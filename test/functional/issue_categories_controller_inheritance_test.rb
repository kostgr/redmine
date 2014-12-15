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
require 'projects_controller'

class IssueCategoriesControllerInheritanceTest < ActionController::TestCase
  fixtures :trackers, :issue_statuses, :enumerations, :workflows, :users

  def setup
    @controller = IssueCategoriesController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    User.current = nil
	@request.session[:user_id] = 1
 
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

  def test_destroy_no_reassign
    is1 = Issue.create! :tracker => @tracker, :project => @pe, :status => @status, :author_id => 1, :subject => 'IS1', :category => @cd1
    delete :destroy, :id => @cd1.id, :todo => "nil"
	is1.reload
	assert_nil is1.category
  end

  def test_destroy_reassign_same_project
    is1 = Issue.create! :tracker => @tracker, :project => @pe, :status => @status, :author_id => 1, :subject => 'IS1', :category => @cd1
    delete :destroy, :id => @cd1.id, :todo => 'reassign', :reassign_to_id => @cd2.id
	is1.reload
	assert_equal @cd2, is1.category
  end

  def test_destroy_reassign_upper_project
    is1 = Issue.create! :tracker => @tracker, :project => @pe, :status => @status, :author_id => 1, :subject => 'IS1', :category => @cd1
    delete :destroy, :id => @cd1.id, :todo => 'reassign', :reassign_to_id => @cb1.id
    is1.reload
	assert_equal @cb1, is1.category
  end

  def test_destroy_reassign_demasked_category
    is1 = Issue.create! :tracker => @tracker, :project => @pe, :status => @status, :author_id => 1, :subject => 'IS1', :category => @cd2
    delete :destroy, :id => @cd2.id, :todo => 'reassign', :reassign_to_id => @cb2.id
    is1.reload
	assert_equal @cb2, is1.category
  end

  def test_categories_list_no_mask
    is1 = Issue.create! :tracker => @tracker, :project => @pe, :status => @status, :author_id => 1, :subject => 'IS1', :category => @cd2
    delete :destroy, :id => @cd2.id
	assert_response(:success)
	assert assigns.has_key?('categories')
	assert_equal [@cb1, @cb2, @cd1], assigns(:categories)
  end

  def test_categories_list_with_mask
    is1 = Issue.create! :tracker => @tracker, :project => @pe, :status => @status, :author_id => 1, :subject => 'IS1', :category => @cd1
    delete :destroy, :id => @cd1.id
	assert_response(:success)
	assert assigns.has_key?('categories')
	assert_equal [@cb1, @cd2], assigns(:categories)
  end

end
