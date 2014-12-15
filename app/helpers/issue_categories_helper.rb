# encoding: utf-8
#
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

module IssueCategoriesHelper
  def options_for_reassign(categ, categs, proj)
    projs = proj.inherited_projects
    cats = categs.sort { |a, b| 
	  (a.project_id == b.project_id) ? (a.name <=> b.name) : (a.project.rgt <=> b.project.rgt)
	}
    return options_for_select(cats.map { |cat|
	  ["#{cat.name} (#{format_project cat.project, projs})", cat.id]
	})
  end

end
