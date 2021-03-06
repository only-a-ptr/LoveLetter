-------------------------------------------------------------------------------
-- Doclet that generates HTML output. This doclet generates a set of html files
-- based on a group of templates. The main templates are:
-- <ul>
-- <li>index.lp: index of modules and files;</li>
-- <li>file.lp: documentation for a lua file;</li>
-- <li>module.lp: documentation for a lua module;</li>
-- <li>function.lp: documentation for a lua function. This is a
-- sub-template used by the others.</li>
-- </ul>
--
-- @release $Id: html.lua,v 1.29 2007/12/21 17:50:48 tomas Exp $
-------------------------------------------------------------------------------

local assert, getfenv, loadstring, pairs, setfenv, tostring, tonumber, type
	= assert, getfenv, loadstring, pairs, setfenv, tostring, tonumber, type
local ipairs, print = ipairs, print;
local io = require "io"
local lfs = require "lfs"
local lp = require "luadoc.lp"
local luadoc = require"luadoc"
local package = package
local string = require"string"
local table = require"table"


local llDoclet = {
	tableConcat = function (self, t, s)
		if t and type(t) == "table" then
			table.concat(t,s)
		else
			print("WARNING: llDoclet:tableConcat(): invalid t: "..tostring(t));
			return tostring(t)
		end
	end
}

module "luadoc.doclet.LoveLetter"

-------------------------------------------------------------------------------
-- Looks for a file `name' in given path. Removed from compat-5.1
-- @param path String with the path.
-- @param name String with the name to look for.
-- @return String with the complete path of the file found
--	or nil in case the file is not found.

local function search (path, name)
  for c in string.gfind(path, "[^;]+") do
    c = string.gsub(c, "%?", name)
    local f = io.open(c)
    if f then   -- file exist?
      f:close()
      return c
    end
  end
  return nil    -- file not found
end

-------------------------------------------------------------------------------
-- Include the result of a lp template into the current stream.

function include (template, env)

	-- template_dir is relative to package.path
	local templatepath = options.template_dir .. template

	-- search using package.path (modified to search .lp instead of .lua
	--[[
	local search_path = string.gsub(package.path, "%.lua", "")
	print(string.format("DBG doclet.include() templatepath:%s\nsearch_path:%s", templatepath, search_path));
	local templatepath = search(search_path, templatepath)
	assert(templatepath, string.format("template `%s' not found", template))--]]

	env = env or {}
	env.table = table
	env.io = io
	env.lp = lp
	env.ipairs = ipairs
	env.pairs = pairs
	env.tonumber = tonumber
	env.tostring = tostring
	env.type = type
	env.luadoc = luadoc
	env.options = options
	env.print = print
	env.llDoclet = llDoclet;

	return lp.include(templatepath, env)
end

-------------------------------------------------------------------------------
-- Returns a link to a html file, appending "../" to the link to make it right.
-- @param html Name of the html file to link to
-- @return link to the html file

function link (html, from)
	local h = html
	from = from or ""
	string.gsub(from, "/", function () h = "../" .. h end)
	return h
end

-------------------------------------------------------------------------------
-- Returns the name of the html file to be generated from a module.
-- Files with "lua" or "luadoc" extensions are replaced by "html" extension.
-- @param modulename Name of the module to be processed, may be a .lua file or
-- a .luadoc file.
-- @return name of the generated html file for the module

function module_link (modulename, doc, from)
	-- TODO: replace "." by "/" to create directories?
	-- TODO: how to deal with module names with "/"?
	assert(modulename)
	assert(doc)
	from = from or ""

	if doc.modules[modulename] == nil then
--		logger:error(string.format("unresolved reference to module `%s'", modulename))
		return
	end

	local href = "modules/" .. modulename .. ".html"
	string.gsub(from, "/", function () href = "../" .. href end)
	return href
end

-------------------------------------------------------------------------------
-- Returns the name of the html file to be generated from a lua(doc) file.
-- Files with "lua" or "luadoc" extensions are replaced by "html" extension.
-- @param to Name of the file to be processed, may be a .lua file or
-- a .luadoc file.
-- @param from path of where am I, based on this we append ..'s to the
-- beginning of path
-- @return name of the generated html file

function file_link (to, from)
	assert(to)
	from = from or ""

	local href = to
	href = string.gsub(href, "lua$", "html")
	href = string.gsub(href, "luadoc$", "html")
	href = "files/" .. href
	string.gsub(from, "/", function () href = "../" .. href end)
	return href
end

-------------------------------------------------------------------------------
-- Returns the name of the html file to be generated from a LL package.
-- @param package_name
-- @param from path of where am I, based on this we append ..'s to the
-- beginning of path
-- @return name of the generated html file for the package

function package_link (package_name, doc, from)
	-- Check args
	assert(package_name, "luadoc.doclet.LoveLetter.package_link(): Missing argument #1 package_name")
	assert(doc, "luadoc.doclet.LoveLetter.package_link(): Missing argument #2 doc")
	from = from or ""

	if doc.packages[package_name] == nil then
		print(string.format("unresolved reference to package `%s'", modulename))
		return
	end

	local href = "packages/" .. package_name .. ".html"
	string.gsub(from, "/", function () href = "../" .. href end)
	return href
end

-------------------------------------------------------------------------------
-- Returns a link to a function or to a table
-- @param fname name of the function or table to link to.
-- @param doc documentation table
-- @param kind String specying the kinf of element to link ("functions" or "tables").

function link_to (fname, doc, module_doc, file_doc, from, kind)
	assert(fname)
	assert(doc)
	from = from or ""
	kind = kind or "functions"

	if file_doc then
		for _, func_name in pairs(file_doc[kind]) do
			if func_name == fname then
				return file_link(file_doc.name, from) .. "#" .. fname
			end
		end
	end

	local _, _, modulename, fname = string.find(fname, "^(.-)[%.%:]?([^%.%:]*)$")
	assert(fname)

	-- if fname does not specify a module, use the module_doc
	if string.len(modulename) == 0 and module_doc then
		modulename = module_doc.name
	end

	local module_doc = doc.modules[modulename]
	if not module_doc then
--		logger:error(string.format("unresolved reference to function `%s': module `%s' not found", fname, modulename))
		return
	end

	for _, func_name in pairs(module_doc[kind]) do
		if func_name == fname then
			return module_link(modulename, doc, from) .. "#" .. fname
		end
	end

--	logger:error(string.format("unresolved reference to function `%s' of module `%s'", fname, modulename))
end

-------------------------------------------------------------------------------
-- Make a link to a file, module or function

function symbol_link (symbol, doc, module_doc, file_doc, from)
	assert(symbol)
	assert(doc)

	local href =
--		file_link(symbol, from) or
		module_link(symbol, doc, from) or
		link_to(symbol, doc, module_doc, file_doc, from, "functions") or
		link_to(symbol, doc, module_doc, file_doc, from, "tables")

	if not href then
		logger:error(string.format("unresolved reference to symbol `%s'", symbol))
	end

	return href or ""
end

-------------------------------------------------------------------------------
-- Assembly the output filename for an input file.

function mk_file_filename(filename)
	local h = filename
	h = string.gsub(h, "lua$", "html")
	h = string.gsub(h, "luadoc$", "html")
	h = "files/" .. h
--	h = options.output_dir .. string.gsub (h, "^.-([%w_]+%.html)$", "%1")
	h = options.output_dir .. h
	return h
end

-------------------------------------------------------------------------------
-- Assembly the output filename for a module.

function mk_module_filename (modulename)
	local h = modulename .. ".html"
	h = "modules/" .. h
	h = options.output_dir .. h
	return h
end

-------------------------------------------------------------------------------
-- Assembly the output filename for a package.

function mk_package_filename (package_name)
	return options.output_dir .. "packages/" .. package_name .. ".html"
end

-------------------------------------------------------------------------------
-- Assembly the output filename for a class.

function mk_class_filename (class_name)
	return options.output_dir .. "classes/" .. class_name .. ".html"
end

-------------------------------------------------------------------------------
-- Generate the output.
-- @param doc Table with the structured documentation.

function start (doc)
	print("Using LoveLetter doclet");
	-- Generate index file
	if (#doc.files > 0 or #doc.modules > 0) and (not options.noindexpage) then
		local filename = options.output_dir.."index.html"
		logger:info(string.format("generating file `%s'", filename))
		local f = lfs.open(filename, "w")
		assert(f, string.format("could not open `%s' for writing", filename))
		io.output(f)
		print("DBG filename:"..filename);
		include("index.lp", { doc = doc })
		f:close()
	end

	-- Process classes
	for _, filepath in ipairs(doc.files) do
		local class_list = doc.files[filepath].classes
		for _, class_name in ipairs(class_list) do
			local class_doc = class_list[class_name]
			-- assembly the filename
			local filename = mk_class_filename(class_doc.name)
			logger:info(string.format("generating file `%s'", filename))

			local f = lfs.open(filename, "w")
			assert(f, string.format("could not open `%s' for writing", filename))
			io.output(f)
			include("class.lp", { doc = doc, class_doc = class_doc} )
			f:close()
		end
	end


	-- Process packages
	if not options.nopackages then
		for _, package_name in ipairs(doc.packages) do
			local package_doc = doc.packages[package_name]
			-- assembly the filename
			local filename = mk_package_filename(package_doc.name)
			logger:info(string.format("generating file `%s'", filename))

			local f = lfs.open(filename, "w")
			assert(f, string.format("could not open `%s' for writing", filename))
			io.output(f)
			include("package.lp", { doc = doc, package_doc = package_doc} )
			f:close()
		end
	end

	-- Process modules
	if not options.nomodules then
		for _, modulename in ipairs(doc.modules) do
			local module_doc = doc.modules[modulename]
			-- assembly the filename
			local filename = mk_module_filename(modulename)
			logger:info(string.format("generating file `%s'", filename))

			local f = lfs.open(filename, "w")
			assert(f, string.format("could not open `%s' for writing", filename))
			io.output(f)
			include("module.lp", { doc = doc, module_doc = module_doc })
			f:close()
		end
	end

	-- Process files
	if not options.nofiles then
		for _, filepath in ipairs(doc.files) do
			local file_doc = doc.files[filepath]
			-- assembly the filename
			local filename = mk_file_filename(file_doc.name)
			logger:info(string.format("generating file `%s'", filename))

			local f = lfs.open(filename, "w")
			assert(f, string.format("could not open `%s' for writing", filename))
			io.output(f)
			include("file.lp", { doc = doc, file_doc = file_doc} )
			f:close()
		end
	end

	-- copy extra files
	local f = lfs.open(options.output_dir.."luadoc.css", "w")
	io.output(f)
	include("luadoc.css")
	f:close()
end
