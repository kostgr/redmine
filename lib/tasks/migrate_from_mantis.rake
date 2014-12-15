# Redmine - project management software
# Copyright (C) 2006-2014  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

desc 'Mantis migration script'

require 'active_record'
require 'iconv' if RUBY_VERSION < '1.9'
require 'pp'

namespace :redmine do
task :migrate_from_mantis => :environment do

  module MantisMigrate

      DEFAULT_STATUS = IssueStatus.default
      reopened_status = IssueStatus.find_by_position(2)
      confirmed_status = IssueStatus.find_by_position(3)
      assigned_status = IssueStatus.find_by_position(4)
      editing_status = IssueStatus.find_by_position(5)
      testing_status = IssueStatus.find_by_position(7)
      resolved_status = IssueStatus.find_by_position(8)
      closed_status = IssueStatus.find_by_position(9)
      STATUS_MAPPING = {10 => DEFAULT_STATUS,  # new
                        20 => reopened_status, # reopened
                        30 => confirmed_status, # acknowledged
                        40 => confirmed_status, # confirmed
                        50 => assigned_status, # assigned
                        60 => editing_status,  # in progress
                        80 => resolved_status, # resolved
                        90 => closed_status    # closed
                        }

      priorities = IssuePriority.all
      DEFAULT_PRIORITY = priorities[1]
      PRIORITY_MAPPING = {10 => priorities[0], # none
                          20 => priorities[0], # low
                          30 => priorities[1], # normal
                          40 => priorities[2], # high
                          50 => priorities[3], # urgent
                          60 => priorities[4]  # immediate
                          }

      TRACKER_BUG = Tracker.find_by_position(1)
      TRACKER_FEATURE = Tracker.find_by_position(2)

      roles = Role.where(:builtin => 0).order('position ASC').all
      manager_role = roles[0]
      developer_role = roles[1]
      DEFAULT_ROLE = roles.last
      ROLE_MAPPING = {10 => DEFAULT_ROLE,   # viewer
                      25 => DEFAULT_ROLE,   # reporter
                      40 => DEFAULT_ROLE,   # updater
                      55 => developer_role, # developer
                      70 => manager_role,   # manager
                      90 => manager_role    # administrator
                      }

      CUSTOM_FIELD_TYPE_MAPPING = {0 => 'string', # String
                                   1 => 'int',    # Numeric
                                   2 => 'int',    # Float
                                   3 => 'list',   # Enumeration
                                   4 => 'string', # Email
                                   5 => 'bool',   # Checkbox
                                   6 => 'list',   # List
                                   7 => 'list',   # Multiselection list
                                   8 => 'date',   # Date
                                   }

      RELATION_TYPE_MAPPING = {1 => IssueRelation::TYPE_RELATES,    # related to
                               2 => IssueRelation::TYPE_RELATES,    # parent of
                               3 => IssueRelation::TYPE_RELATES,    # child of
                               0 => IssueRelation::TYPE_DUPLICATES, # duplicate of
                               4 => IssueRelation::TYPE_DUPLICATES  # has duplicate
                               }

    class MantisUser < ActiveRecord::Base
      self.table_name = :mantis_user_table

      def firstname
        @firstname = realname.blank? ? username : realname.split.first[0..29]
        @firstname
      end

      def lastname
        @lastname = realname.blank? ? '-' : realname.split[1..-1].join(' ')[0..29]
        @lastname = '-' if @lastname.blank?
        @lastname
      end

      def email
        if read_attribute(:email).match(/^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i) &&
             !User.find_by_mail(read_attribute(:email))
          @email = read_attribute(:email)
        else
          @email = "#{username}@foo.bar"
        end
      end

      def username
        read_attribute(:username)[0..29].gsub(/[^a-zA-Z0-9_\-@\.]/, '-')
      end
    end

    class MantisProject < ActiveRecord::Base
      self.table_name = :mantis_project_table
      has_many :versions, :class_name => "MantisVersion", :foreign_key => :project_id
      has_many :categories, :class_name => "MantisCategory", :foreign_key => :project_id
      has_many :news, :class_name => "MantisNews", :foreign_key => :project_id
      has_many :members, :class_name => "MantisProjectUser", :foreign_key => :project_id

      def identifier
        read_attribute(:name).slice(0, Project::IDENTIFIER_MAX_LENGTH).downcase.gsub(/[^a-z0-9\-]+/, '-')
      end
    end

    class MantisProjectHierarchy < ActiveRecord::Base
        self.table_name = :mantis_project_hierarchy_table
    end

    class MantisVersion < ActiveRecord::Base
      self.table_name = :mantis_project_version_table

      def version
        read_attribute(:version)[0..29]
      end

      def description
        read_attribute(:description)[0..254]
      end
    end

    class MantisCategory < ActiveRecord::Base
      self.table_name = :mantis_category_table
      def category
        read_attribute(:name).slice(0,70)
      end
    end

    class MantisProjectUser < ActiveRecord::Base
      self.table_name = :mantis_project_user_list_table
    end

    class MantisBug < ActiveRecord::Base
      self.table_name = :mantis_bug_table
      belongs_to :bug_text, :class_name => "MantisBugText", :foreign_key => :bug_text_id
      belongs_to :category, :class_name => "MantisCategory", :foreign_key => :category_id
      has_many :bug_notes, :class_name => "MantisBugNote", :foreign_key => :bug_id
      has_many :bug_files, :class_name => "MantisBugFile", :foreign_key => :bug_id
      has_many :bug_monitors, :class_name => "MantisBugMonitor", :foreign_key => :bug_id
    end

    class MantisBugText < ActiveRecord::Base
      self.table_name = :mantis_bug_text_table

      # Adds Mantis steps_to_reproduce and additional_information fields
      # to description if any
      def full_description
        full_description = description
        full_description += "\n\n*Steps to reproduce:*\n\n#{steps_to_reproduce}" unless steps_to_reproduce.blank?
        full_description += "\n\n*Additional information:*\n\n#{additional_information}" unless additional_information.blank?
        full_description
      end
    end

    class MantisBugNote < ActiveRecord::Base
      self.table_name = :mantis_bugnote_table
      belongs_to :bug, :class_name => "MantisBug", :foreign_key => :bug_id
      belongs_to :bug_note_text, :class_name => "MantisBugNoteText", :foreign_key => :bugnote_text_id
    end

    class MantisBugNoteText < ActiveRecord::Base
      self.table_name = :mantis_bugnote_text_table
    end

    class MantisBugFile < ActiveRecord::Base
      self.table_name = :mantis_bug_file_table

      def size
        filesize
      end

      def original_filename
        MantisMigrate.encode(filename)
      end

      def content_type
        file_type
      end

      def read(*args)
          if @read_finished
              nil
          else
              @read_finished = true
              content
          end
      end
    end

    class MantisBugRelationship < ActiveRecord::Base
      self.table_name = :mantis_bug_relationship_table
    end

    class MantisBugMonitor < ActiveRecord::Base
      self.table_name = :mantis_bug_monitor_table
    end

    class MantisNews < ActiveRecord::Base
      self.table_name = :mantis_news_table
    end

    class MantisCustomField < ActiveRecord::Base
      self.table_name = :mantis_custom_field_table
      self.inheritance_column = :none
      has_many :values, :class_name => "MantisCustomFieldString", :foreign_key => :field_id
      has_many :projects, :class_name => "MantisCustomFieldProject", :foreign_key => :field_id

      def format
        read_attribute :type
      end

      def name
        read_attribute(:name)[0..29]
      end
    end

    class MantisCustomFieldProject < ActiveRecord::Base
      self.table_name = :mantis_custom_field_project_table
    end

    class MantisCustomFieldString < ActiveRecord::Base
      self.table_name = :mantis_custom_field_string_table
    end

    def self.migrate

      # Users
      print "Migrating users"
      User.delete_all "login <> 'admin'"
      users_map = {}
      users_migrated = 0
      MantisUser.all.each do |user|
        u = User.new :firstname => encode(user.firstname),
                     :lastname => encode(user.lastname),
                     :mail => user.email,
                     :last_login_on => (user.last_visit ? Time.at(user.last_visit) : nil)
        u.login = user.username
        u.password = 'mantis'
        u.status = User::STATUS_LOCKED if user.enabled != 1
        u.admin = true if user.access_level == 90
        next unless u.save!
        users_migrated += 1
        users_map[user.id] = u.id
        print '.'
      end
      puts

      # Projects
      print "Migrating projects"
      Project.destroy_all
      projects_map = {}
      versions_map = {}
      versions_locked = []
      categories_map = {}
      inheritable_categories = false
      MantisProject.all.each do |project|
        p = Project.new :name => encode(project.name),
                        :description => encode(project.description)
        inheritable_categories = p.has_attribute?("inherit_categs") unless inheritable_categories
        p.identifier = project.identifier
        p.is_public = (project.view_state == 10)
        next unless p.save
        projects_map[project.id] = p.id
        p.enabled_module_names = ['issue_tracking', 'news', 'calendar', 'gantt', 'time_tracking']
        p.trackers << TRACKER_BUG unless p.trackers.include?(TRACKER_BUG)
        p.trackers << TRACKER_FEATURE unless p.trackers.include?(TRACKER_FEATURE)
        print '.'

        # Project members
        project.members.each do |member|
          m = Member.new :user => User.find_by_id(users_map[member.user_id]),
                           :roles => [ROLE_MAPPING[member.access_level] || DEFAULT_ROLE]
          m.project = p
          m.save
        end

        # Project versions
        project.versions.each do |version|
          v = Version.new :name => encode(version.version),
                          :description => encode(version.description),
                          :effective_date => (version.date_order ? Time.at(version.date_order).to_date : nil)
          v.project = p
          # we cannot directly lock versions, cause otherwise some bugs will not be migrated, that why we remember the versions to be locked after issues migration
          if version.obsolete == 1
            versions_locked << v
          end
          v.save
          versions_map[version.id] = v.id
        end

        # Project categories
        project.categories.each do |category|
          g = IssueCategory.new :name => category.category
          g.project = p
          g.save
          categories_map[category.category] = g.id
        end
      end
      puts

      # Project Hierarchy
      print "Making Project Hierarchy"
      MantisProjectHierarchy.find(:all).each do |link|
        next unless p = Project.find_by_id(projects_map[link.child_id])
        p.set_parent!(projects_map[link.parent_id])
        if link.inherit_parent == 1
          if inheritable_categories
            p.inherit_categs = 1
          end
          # Turn on the users inheritance
          p.inherit_members = 1
          p.save
          # Turn on the versions inheritance
          parent_project = Project.find_by_id(projects_map[link.parent_id])
          parent_project.versions.each do |version|
            version.sharing = 'descendants'
            version.save
          end
        end
        print '.'
      end
      puts

      # Bugs
      print "Migrating bugs"
      ActiveRecord::Base.record_timestamps = false
      Issue.destroy_all
      issues_map = {}
      keep_bug_ids = (Issue.count == 0)
      MantisBug.find_each(:batch_size => 200) do |bug|
        if !(projects_map[bug.project_id] && users_map[bug.reporter_id])
          puts "<#{bug.id} proj/user er>"
          next
        end
        i = Issue.new :project_id => projects_map[bug.project_id],
                      :subject => encode(bug.summary),
                      :description => encode(bug.bug_text.full_description),
                      :priority => PRIORITY_MAPPING[bug.priority] || DEFAULT_PRIORITY,
                      :created_on => (bug.date_submitted ? Time.at(bug.date_submitted) : nil),
                      :updated_on => (bug.last_updated ? Time.at(bug.last_updated) : nil)
        i.author = User.find_by_id(users_map[bug.reporter_id])
        i.category = IssueCategory.find_by_project_id_and_name(i.project_id, bug.category.category) unless bug.category.blank?
        if (i.category.nil?) && inheritable_categories
          p = Project.find_by_id(projects_map[bug.project_id])
          i.category = p.inherited_categories.find{|c| c.name == bug.category.category}
        end
        if !(bug.fixed_in_version.blank? && bug.target_version.blank?)
          p = Project.find_by_id(projects_map[bug.project_id])
          if !bug.fixed_in_version.blank?
            vv = bug.fixed_in_version
          else
            vv = bug.target_version
          end
          i.fixed_version = p.shared_versions.find{|v| v.name == vv}
        end
        i.status = STATUS_MAPPING[bug.status] || DEFAULT_STATUS
        i.tracker = (bug.severity == 10 ? TRACKER_FEATURE : TRACKER_BUG)
        i.start_date = Time.at(bug.date_submitted).to_date
        if bug.due_date > bug.date_submitted
          i.due_date = Time.at(bug.due_date).to_date
        elsif bug.status >= 80 && bug.last_updated > bug.date_submitted
          i.due_date = Time.at(bug.last_updated).to_date
        end
        i.id = bug.id if keep_bug_ids
        if !i.save
          puts "<#{bug.id} save er>"
          puts i.errors.full_messages.join(', ')
          STDIN.gets.chomp!
          next
        end
        # next unless i.save
        issues_map[bug.id] = i.id
        print '.'
        STDOUT.flush

        # Assignee
        # Redmine checks that the assignee is a project member
        if (bug.handler_id && users_map[bug.handler_id])
          i.assigned_to = User.find_by_id(users_map[bug.handler_id])
          i.save(:validate => false)
        end

        # Bug notes
        bug.bug_notes.each do |note|
          next unless users_map[note.reporter_id]
          n = Journal.new :notes => encode(note.bug_note_text.note),
                          :created_on => Time.at(note.date_submitted)
          n.user = User.find_by_id(users_map[note.reporter_id])
          n.journalized = i
          n.save
        end

        # Bug files
        bug.bug_files.each do |file|
          a = Attachment.new :created_on => (file.date_added ? Time.at(file.date_added) : nil)
          a.file = file
          a.author = User.first
          a.container = i
          a.save
        end

        # Bug monitors
        bug.bug_monitors.each do |monitor|
          next unless users_map[monitor.user_id]
          i.add_watcher(User.find_by_id(users_map[monitor.user_id]))
        end
      end

      # Locking versions after all bugs where migrated, otherwise no bugs with the locked version as target will be migrated
      versions_locked.each do |version|
        version.status = 'locked'
        version.save
      end

      # update issue id sequence if needed (postgresql)
      Issue.connection.reset_pk_sequence!(Issue.table_name) if Issue.connection.respond_to?('reset_pk_sequence!')
      puts

      # Bug relationships
      ActiveRecord::Base.record_timestamps = true
      print "Migrating bug relations"
      MantisBugRelationship.all.each do |relation|
        next unless issues_map[relation.source_bug_id] && issues_map[relation.destination_bug_id]
        r = IssueRelation.new :relation_type => RELATION_TYPE_MAPPING[relation.relationship_type]
        r.issue_from = Issue.find_by_id(issues_map[relation.source_bug_id])
        r.issue_to = Issue.find_by_id(issues_map[relation.destination_bug_id])
        pp r unless r.save
        print '.'
        STDOUT.flush
      end
      puts

      # News
      print "Migrating news"
      News.destroy_all
      MantisNews.where('project_id > 0').all.each do |news|
        next unless projects_map[news.project_id]
        n = News.new :project_id => projects_map[news.project_id],
                     :title => encode(news.headline[0..59]),
                     :description => encode(news.body),
                     :created_on => Time.at(news.date_posted)
        n.author = User.find_by_id(users_map[news.poster_id])
        n.save
        print '.'
        STDOUT.flush
      end
      puts

      # Custom fields
      print "Migrating custom fields"
      IssueCustomField.destroy_all
      MantisCustomField.all.each do |field|
        f = IssueCustomField.new :name => field.name[0..29],
                                 :field_format => CUSTOM_FIELD_TYPE_MAPPING[field.format],
                                 :min_length => field.length_min,
                                 :max_length => field.length_max,
                                 :regexp => field.valid_regexp,
                                 :possible_values => field.possible_values.split('|'),
                                 :is_required => field.require_report?
        next unless f.save
        print '.'
        STDOUT.flush
        # Trackers association
        f.trackers = Tracker.all

        # Projects association
        field.projects.each do |project|
          f.projects << Project.find_by_id(projects_map[project.project_id]) if projects_map[project.project_id]
        end

        # Values
        field.values.each do |value|
          v = CustomValue.new :custom_field_id => f.id,
                              :value => value.value
          v.customized = Issue.find_by_id(issues_map[value.bug_id]) if issues_map[value.bug_id]
          v.save
        end unless f.new_record?
      end

      puts

      puts
      puts "Users:           #{users_migrated}/#{MantisUser.count}"
      puts "Projects:        #{Project.count}/#{MantisProject.count}"
      puts "Memberships:     #{Member.count}/#{MantisProjectUser.count}"
      puts "Versions:        #{Version.count}/#{MantisVersion.count}"
      puts "Categories:      #{IssueCategory.count}/#{MantisCategory.count}"
      puts "Bugs:            #{Issue.count}/#{MantisBug.count}"
      puts "Bug notes:       #{Journal.count}/#{MantisBugNote.count}"
      puts "Bug files:       #{Attachment.count}/#{MantisBugFile.count}"
      puts "Bug relations:   #{IssueRelation.count}/#{MantisBugRelationship.count}"
      puts "Bug monitors:    #{Watcher.count}/#{MantisBugMonitor.count}"
      puts "News:            #{News.count}/#{MantisNews.count}"
      puts "Custom fields:   #{IssueCustomField.count}/#{MantisCustomField.count}"
    end

    def self.encoding(charset)
      @charset = charset
    end

    def self.establish_connection(params)
      constants.each do |const|
        klass = const_get(const)
        next unless klass.respond_to? 'establish_connection'
        klass.establish_connection params
      end
    end

    def self.encode(text)
      if RUBY_VERSION < '1.9'
        @ic ||= Iconv.new('UTF-8', @charset)
        @ic.iconv text
      else
        text.to_s.force_encoding(@charset).encode('UTF-8')
      end
    end
  end

  puts
  if Redmine::DefaultData::Loader.no_data?
    puts "Redmine configuration need to be loaded before importing data."
    puts "Please, run this first:"
    puts
    puts "  rake redmine:load_default_data RAILS_ENV=\"#{ENV['RAILS_ENV']}\""
    exit
  end

  puts "WARNING: Your Redmine data will be deleted during this process."
  print "Are you sure you want to continue ? [y/N] "
  STDOUT.flush
  break unless STDIN.gets.match(/^y$/i)

  # Default Mantis database settings
  db_params = {:adapter => 'mysql2',
               :database => 'bugtracker',
               :host => 'localhost',
               :username => 'root',
               :password => '' }

  puts
  puts "Please enter settings for your Mantis database"
  [:adapter, :host, :database, :username, :password].each do |param|
    print "#{param} [#{db_params[param]}]: "
    value = STDIN.gets.chomp!
    db_params[param] = value unless value.blank?
  end

  while true
    print "encoding [UTF-8]: "
    STDOUT.flush
    encoding = STDIN.gets.chomp!
    encoding = 'UTF-8' if encoding.blank?
    break if MantisMigrate.encoding encoding
    puts "Invalid encoding!"
  end
  puts

  # Make sure bugs can refer bugs in other projects
  Setting.cross_project_issue_relations = 1 if Setting.respond_to? 'cross_project_issue_relations'

  old_notified_events = Setting.notified_events
  old_password_min_length = Setting.password_min_length
  begin
    # Turn off email notifications temporarily
    Setting.notified_events = []
    Setting.password_min_length = 4
    # Run the migration
    MantisMigrate.establish_connection db_params
    MantisMigrate.migrate
  ensure
    # Restore previous settings
    Setting.notified_events = old_notified_events
    Setting.password_min_length = old_password_min_length
  end

end
end
