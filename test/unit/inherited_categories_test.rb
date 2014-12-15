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

class InheritedCategoriesTest < ActiveSupport::TestCase
  fixtures :trackers, :issue_statuses, :enumerations, :workflows, :users

  def setup
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

  def test_inherited_project_self
  	assert_equal [ @pb ], @pb.inherited_projects
  	assert_equal [ @pa ], @pa.inherited_projects
  end

  def test_inherited_project
    assert_equal [ @pd, @pc, @pb ], @pd.inherited_projects
  end

  def test_inherited_categories_self
  	assert_equal @pa.issue_categories, @pa.inherited_categories
  	assert_equal @pb.issue_categories, @pb.inherited_categories
  	assert_equal @pg.issue_categories, @pg.inherited_categories
  end

  def test_inherited_categories
    assert_equal [ @cb1, @cd2, @cd1 ], @pd.inherited_categories
    assert_equal [ @cb1, @cd2, @cd1 ], @pe.inherited_categories
	assert @pg.inherited_categories.empty?
  end

  def test_adjust_inheritance_to_nil
  	is1 = Issue.create!(:project => @pe, :tracker => @tracker, :status => @status, :author_id => 1, :subject => 'issueb', :category => @cb1)
  	is2 = Issue.create!(:project => @pe, :tracker => @tracker, :status => @status, :author_id => 1, :subject => 'issued', :category => @cd1)
	@pc.send :adjust_inheritance, @pb, nil
	assert ! @pc.inherit_categs
	@pc.reload
	assert ! @pc.inherit_categs
	is1.reload
	is2.reload
	assert_equal @cd1, is2.category
	assert_equal 1, @pc.issue_categories.size
	cat = @pc.issue_categories[0]
	assert_equal cat, is1.category
	assert_equal @cb1.name, cat.name
  end

  def test_adjust_inheritance_with_loss
  	is1 = Issue.create!(:project => @pd, :tracker => @tracker, :status => @status, :author_id => 1, :subject => 'issueb', :category => @cb1)
  	is2 = Issue.create!(:project => @pd, :tracker => @tracker, :status => @status, :author_id => 1, :subject => 'issued', :category => @cd1)
	@pc.send :adjust_inheritance, @pb, @pa
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
	@pd.send :adjust_inheritance, @pc, @pf
	is1.reload
	is2.reload
	assert_equal @cd1, is2.category
	assert @pc.issue_categories.empty?
	assert_equal @cb1, is1.category
  end

end
