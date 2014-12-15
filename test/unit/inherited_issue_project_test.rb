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

require File.expand_path('../../test_helper', __FILE__)

class InheritedIssueProjectTest < ActiveSupport::TestCase
  fixtures :trackers, :issue_statuses, :enumerations, :workflows, :users

  def setup
	wt = WorkflowTransition.find(:first)
	@tracker = wt.tracker
	@status = wt.old_status

	@pa = Project.create!(:name => 'A', :identifier => 'a')
	@pb = Project.create!(:name => 'B', :identifier => 'b', :parent_id => @pa.id, :trackers => [@tracker])
	@pc = Project.create!(:name => 'C', :identifier => 'c', :parent_id => @pa.id, :inherit_categs => true, :trackers => [@tracker])
	@pa.reload
	@pb.reload
	@pc.reload
	@ca0 = IssueCategory.create!(:project => @pa, :name => 'ca0')
	@ca1 = IssueCategory.create!(:project => @pa, :name => 'ca1')
  end

  def test_change_to_parent
    is1 = Issue.create! :tracker => @tracker, :project => @pc, :status => @status, :author_id => 1, :subject => 'IS1', :category => @ca1
	assert_equal is1.category, @ca1
	is1.project = @pa
	assert_equal is1.category, @ca1
  end

  def test_change_to_non_inherit_child
    is1 = Issue.create! :tracker => @tracker, :project => @pa, :status => @status, :author_id => 1, :subject => 'IS1', :category => @ca1
	assert_equal is1.category, @ca1
	is1.project_id = @pb.id
	assert_nil is1.category
  end

  def test_change_to_inherit_child
    is1 = Issue.create! :tracker => @tracker, :project => @pa, :status => @status, :author_id => 1, :subject => 'IS1', :category => @ca1
	assert_equal is1.category, @ca1
	is1.project_id = @pc.id
	assert_equal is1.category, @ca1
  end
end
