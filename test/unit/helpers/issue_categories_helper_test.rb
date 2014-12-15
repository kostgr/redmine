# encoding: utf-8

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

require File.expand_path('../../../test_helper', __FILE__)

class IssueCategoryHelperTest < ActionView::TestCase
  include IssueCategoriesHelper
  include ApplicationHelper

  fixtures :trackers, :issue_statuses, :enumerations, :users, :workflows

  def setup
    super
	User.current = nil
	wt = WorkflowTransition.find(:first)
	@tracker = wt.tracker
	@status = wt.old_status

	@pa = Project.create!(:name => 'A', :identifier => 'a')
	@pb = Project.create!(:name => 'B', :identifier => 'b', :trackers => [@tracker])
	@pc = Project.create!(:name => 'C', :identifier => 'c', :parent_id => @pb.id, :inherit_categs => true, :trackers => [@tracker])
	@pd = Project.create!(:name => 'D', :identifier => 'd', :parent_id => @pc.id, :inherit_categs => true, :trackers => [@tracker])
	@pe = Project.create!(:name => 'E', :identifier => 'e', :parent_id => @pd.id, :inherit_categs => true, :trackers => [@tracker])
	@pf = Project.create!(:name => 'F', :identifier => 'f', :parent_id => @pb.id, :inherit_categs => true, :trackers => [@tracker])
	@pg = Project.create!(:name => 'G', :identifier => 'g', :trackers => [@tracker])
	@pa.reload
	@pb.reload
	@pc.reload
	@pd.reload
	@pd.reload
	@ca1 = IssueCategory.create!(:project => @pa, :name => 'ca1')
	@cb1 = IssueCategory.create!(:project => @pb, :name => 'cb1')
	@cb2 = IssueCategory.create!(:project => @pb, :name => 'cb2')
	@cd1 = IssueCategory.create!(:project => @pd, :name => 'cd1')
	@cd2 = IssueCategory.create!(:project => @pd, :name => 'cb2')
  end

  def test_format_project
    list = @pe.inherited_projects
	assert_equal 'B » C » D', format_project(@pd, list)
	assert_equal 'B', format_project(@pb, list)
	assert_equal 'B » C » D » E', format_project(@pe, list)
  end

  def test_options_for_reassign_no_inheritance
    @pd.inherit_categs = false
	@pd.save
	categs = @pd.inherited_categories - [@cd1]
	assert_equal "<option value=\"#{@cd2.id}\">cb2 (D)</option>", options_for_reassign(@cd1, categs, @pd)
  end

  def test_options_for_reassign_with_masked_categ
    categs = @pd.inherited_categories - [ @cd1 ]
	assert_equal "<option value=\"#{@cd2.id}\">cb2 (B » C » D)</option>\n<option value=\"#{@cb1.id}\">cb1 (B)</option>", options_for_reassign(@cd1, categs, @pd)
  end

  def test_options_for_reassign_no_masked_categ
    categs = (@pd.issue_categories | @pc.inherited_categories) - [ @cd2 ]
	assert_equal "<option value=\"#{@cd1.id}\">cd1 (B » C » D)</option>\n<option value=\"#{@cb1.id}\">cb1 (B)</option>\n<option value=\"#{@cb2.id}\">cb2 (B)</option>", options_for_reassign(@cd1, categs, @pd)
  end

end
