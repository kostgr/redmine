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

class ProjectsControllerInheritanceTest < ActionController::TestCase
  fixtures :trackers, :issue_statuses, :enumerations, :workflows, :users

  def setup
    @controller = ProjectsController.new
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

  def test_adjust_set_inherit_to_false
  	is1 = Issue.create!(:project => @pe, :tracker => @tracker, :status => @status, :author_id => 1, :subject => 'issueb', :category => @cb1)
  	is2 = Issue.create!(:project => @pe, :tracker => @tracker, :status => @status, :author_id => 1, :subject => 'issued', :category => @cd1)
	post :update, :id => @pc.identifier, :project => {:inherit_categs => "0"}
	assert_response(:redirect)
	assert_redirected_to "/projects/#{@pc.identifier}/settings"
	@pc.reload
	assert ! @pc.inherit_categs
	assert_equal @pb, @pc.parent
	is1.reload
	is2.reload
	assert_equal @cd1, is2.category
	assert_equal 1, @pc.issue_categories.size
	cat = @pc.issue_categories[0]
	assert_equal cat, is1.category
	assert_equal @cb1.name, cat.name
  end

  def test_adjust_set_parent_nil
  	is1 = Issue.create!(:project => @pe, :tracker => @tracker, :status => @status, :author_id => 1, :subject => 'issueb', :category => @cb1)
  	is2 = Issue.create!(:project => @pe, :tracker => @tracker, :status => @status, :author_id => 1, :subject => 'issued', :category => @cd1)
	post :update, :id => @pc.identifier, :project => {:parent_id => ""}
	assert_response(:redirect)
	assert_redirected_to "/projects/#{@pc.identifier}/settings"
	@pc.reload
	assert ! @pc.inherit_categs
	assert_nil @pc.parent
	is1.reload
	is2.reload
	assert_equal @cd1, is2.category
	assert_equal 1, @pc.issue_categories.size
	cat = @pc.issue_categories[0]
	assert_equal cat, is1.category
	assert_equal @cb1.name, cat.name
  end

  def test_adjust_inheritance_with_loss
  	is1 = Issue.create!(:project => @pe, :tracker => @tracker, :status => @status, :author_id => 1, :subject => 'issueb', :category => @cb1)
  	is2 = Issue.create!(:project => @pe, :tracker => @tracker, :status => @status, :author_id => 1, :subject => 'issued', :category => @cd1)
	post :update, :id => @pc.identifier, :project => {:parent_id => @pa.id}
	assert_response(:redirect)
	assert_redirected_to "/projects/#{@pc.identifier}/settings"
	@pc.reload
	assert @pc.inherit_categs
	assert_equal @pa, @pc.parent
	is1.reload
	is2.reload
	assert_equal @cd1, is2.category
	assert_equal 1, @pc.issue_categories.size
	cat = @pc.issue_categories[0]
	assert_equal cat, is1.category
	assert_equal @cb1.name, cat.name
  end

  def test_adjust_inheritance_no_loss
  	is1 = Issue.create!(:project => @pe, :tracker => @tracker, :status => @status, :author_id => 1, :subject => 'issueb', :category => @cb1)
  	is2 = Issue.create!(:project => @pe, :tracker => @tracker, :status => @status, :author_id => 1, :subject => 'issued', :category => @cd1)
	post :update, :id => @pd.identifier, :project => {:parent_id => @pf.id}
	assert_redirected_to "/projects/#{@pd.identifier}/settings"
	@pd.reload
	assert @pd.inherit_categs
	assert_equal @pf, @pd.parent
	is1.reload
	is2.reload
	assert_equal @cd1, is2.category
	assert_equal 2, @pd.issue_categories.size
	assert_equal @cb1, is1.category
  end

  def test_set_inherit
    @pf.inherit_categs = false
	@pf.save!
	@pf.reload
	assert ! @pf.inherit_categs
	post :update, :id => @pf.identifier, :project => {:inherit_categs => true}
	assert_redirected_to "/projects/#{@pf.identifier}/settings"
	@pf.reload
	assert @pf.inherit_categs
  end

  def test_create_inheritant_project
    post :create, :project => { :name => 'H', :identifier => 'h', :parent_id => @pb.id,
      :inherit_categs => true}
    ph = Project.find_by_identifier('h')
    assert ph.inherit_categs
  end

end
