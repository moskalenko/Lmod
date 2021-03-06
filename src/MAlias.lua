--------------------------------------------------------------------------
-- This class is a singleton controlling the version and alias mapping.
-- Site create .modulerc files to specify that certain strings can be
-- also know as.  Here are some examples:
--
-- In the intel/ directory there might be a .modulerc file that can
-- contain:
--
--    #%Module
--    module-version intel/15.0.3 default 15.0 15
--    module-version /14.0.1 default 14.0 14
--
-- Note that a leading slash means that it matches the directory name
-- (i.e. intel).  There can only be one default.  In this case the last
-- one controls.
--    
--
-- @classmod MAlias

require("strict")

--------------------------------------------------------------------------
-- Lmod License
--------------------------------------------------------------------------
--
--  Lmod is licensed under the terms of the MIT license reproduced below.
--  This means that Lmod is free software and can be used for both academic
--  and commercial purposes at absolutely no cost.
--
--  ----------------------------------------------------------------------
--
--  Copyright (C) 2008-2015 Robert McLay
--
--  Permission is hereby granted, free of charge, to any person obtaining
--  a copy of this software and associated documentation files (the
--  "Software"), to deal in the Software without restriction, including
--  without limitation the rights to use, copy, modify, merge, publish,
--  distribute, sublicense, and/or sell copies of the Software, and to
--  permit persons to whom the Software is furnished to do so, subject
--  to the following conditions:
--
--  The above copyright notice and this permission notice shall be
--  included in all copies or substantial portions of the Software.
--
--  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
--  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
--  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
--  NONINFRINGEMENT.  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
--  BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
--  ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
--  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
--  THE SOFTWARE.
--
--------------------------------------------------------------------------


s_malias     = {} 
local M      = {}
local dbg    = require("Dbg"):dbg()
local concat = table.concat
local getenv = os.getenv
--------------------------------------------------------------------------
-- a private ctor that is used to construct a singleton.
-- @param self A MAlias object.

local function new(self)
   local o         = {}
   o.version2modT  = {}  -- Map a sn/version string to a module fullname
   o.alias2modT    = {}  -- Map an alias string to a module name or alias
   o.defaultT      = {}  -- Map module sn to fullname that is the default.
   o.mod2versionsT = {}  -- Map from full module name to versions.

   setmetatable(o,self)
   self.__index = self
   return o
end

--------------------------------------------------------------------------
-- A singleton Ctor for the MAlias class
-- @param self A MAlias object.

function M.build(self)
   dbg.start{"MAlias:build()"}
   if (next(s_malias) == nil) then
      s_malias = new(self)
   end
   dbg.fini("MAlias:build")
   return s_malias
end

function M.getDefaultT(self, key)
   local defaultT= self.defaultT
   return defaultT[key]
end

function M.parseModA(self, sn, modA)
   dbg.start{"MAlias:parseModA(",sn,", modA)"}
   for i = 1, #modA do
      local entry   = modA[i]
      dbg.print{"entry.kind: ",entry.kind, "\n"}

      if (entry.kind == "module-version") then
         local modname = entry.module_name
         dbg.print{"modname: ",modname, "\n"}
         if (modname:sub(1,1) == '/') then
            modname = sn .. modname
         end
         dbg.print{"(2) modname: ",modname, "\n"}
         local a = entry.module_versionA
         for j = 1, #a do
            version = a[j]
            local _, _, short, mversion = modname:find("(.*)/(.*)")
            dbg.print{"j: ",j, ", version: ",version, "\n"}
            if (version == "default") then
               dbg.print{"Setting default sn: ",short, ", to version: ",mversion,"\n"}
               self.defaultT[short]        = mversion
            else
               local key = short .. "/" .. version
               self.version2modT[key] = modname
               dbg.print{"v2m: key: ",key,": ",modname,"\n"}
            end
         end
      elseif (entry.kind == "module-alias") then
         dbg.print{"name: ",entry.name,", mfile: ", entry.mfile,"\n"}
         self.alias2modT[entry.name] = entry.mfile
      end
   end
   dbg.fini("MAlias:parseModA")
end




s_must_read_global_rc_files = true

modA = false
function M.resolve(self, name)
   
   ------------------------------------------------------------------------
   -- we must guarantees that the directory has been walked.
   local mt = _G.MT:mt()
   mt:locationTbl() 

   ------------------------------------------------------------------------
   -- Read in system and user RC files.
   if (s_must_read_global_rc_files) then
      s_must_read_global_rc_files = false

      local fileA = {MODULERCFILE, pathJoin(getenv("HOME"),".modulerc") }
      for i = 1, #fileA  do
         local fn = fileA[i]
         if (isFile(fn)) then
            local cmd = pathJoin(cmdDir(),"RC2lua.tcl") .. " " .. fn
            local s   = capture(cmd):trim()
            modA      = {}
            assert(load(s))()
            self:parseModA("", modA)
         end
      end
   end

   local value = self.alias2modT[name]
   if (value ~= nil) then
      name  = value
      value = self:resolve(value)
   end

   value = self.version2modT[name]
   if (value == nil) then
      value = name
   else
      name  = value
      value = self:resolve(value)
   end
   return value
end

function M.buildMod2VersionT(self)

   local v2mT = self.version2modT
   local m2vT = {}
   local t
   for k, v in pairs(v2mT) do
      v       = self:resolve(v)
      t       = m2vT[v] or {}
      t[k]    = true
      m2vT[v] = t
   end
   for modname, vv in pairs(m2vT) do
      local a = {}
      for k in pairsByKeys(vv) do
         a[#a+1] = k:gsub("^.*/","")
      end
      m2vT[modname] = concat(a,":")
   end
   self.mod2versionT = m2vT
end

function M.getMod2VersionT(self, key)
   return self.mod2versionT[key]
end

return M
