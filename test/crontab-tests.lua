--------------------------------------------------------------------------------
-- crontab-tests.lua: tests for crontab
-- This file is a part of lua-crontab library
-- Copyright (c) 2010-2021 lua-crontab authors
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local unpack = unpack or table.unpack -- for Lua 5.1 / 5.4 compatibility
require 'lua-nucleo'

--------------------------------------------------------------------------------

local make_suite = select(1, ...)
assert(type(make_suite) == "function")

--------------------------------------------------------------------------------

local arguments,
      optional_arguments
      = import 'lua-nucleo/args.lua'
      {
        'arguments',
        'optional_arguments'
      }

local ensure,
      ensure_equals,
      ensure_strequals,
      ensure_tdeepequals,
      ensure_fails_with_substring
      = import 'lua-nucleo/ensure.lua'
      {
        'ensure',
        'ensure_equals',
        'ensure_strequals',
        'ensure_tdeepequals',
        'ensure_fails_with_substring'
      }

local assert_is_table
      = import 'lua-nucleo/typeassert.lua'
      {
        'assert_is_table'
      }

local is_string,
      is_table
      = import 'lua-nucleo/type.lua'
      {
        'is_string',
        'is_table'
      }

local tstr
      = import 'lua-nucleo/table.lua'
      {
        'tstr'
      }

local make_timestamp_from_string
      = import 'lua-nucleo/timestamp.lua'
      {
        'make_timestamp_from_string'
      }

local make_crontab,
      make_cron_properties,
      make_raw_cron_data_from_string,
      make_next_occurrence_getter,
      exports
      = import 'crontab/crontab.lua'
      {
        'make_crontab',
        'make_cron_properties',
        'make_raw_cron_data_from_string',
        'make_next_occurrence_getter'
      }

--------------------------------------------------------------------------------

local CRON_DATA = { field1 = "value1" }

--------------------------------------------------------------------------------

local test = make_suite("crontab", exports)

--------------------------------------------------------------------------------

local run_tests
do
  local run_group_tests = function(prefix, group_name, group_data, check_fn)
      arguments(
          "string",   prefix,
          "string",   group_name,
          "table",    group_data,
          "function", check_fn
        )

      for _, v in pairs(group_data) do
        local test_spec = is_string(v[2]) and v[2] or tstr(v[2])
        local test_unique_name =
          v[1] .. "-" .. test_spec .. (v[3] and "-" .. v[3] or "")
        test:case (prefix .. "-" .. group_name .. "-" .. test_unique_name) (
            function()
              check_fn(unpack(v))
            end
          )
      end
    end

  run_tests = function(name, data, check_fn)
    arguments(
        "string",   name,
        "table",    data,
        "function", check_fn
      )
    for k, v in pairs(data) do
      run_group_tests(name, k, v, check_fn)
    end
  end
end

--------------------------------------------------------------------------------

test:group "make_crontab"

test:case "empty" (function()
  local crontab_data = {}
  ensure("crontab", is_table(make_crontab(crontab_data)))
end)

test:case "simple array" (function()
  local crontab_data = {
    { "*", "*", "*", "*", "*", "*", CRON_DATA }
  }
  ensure("crontab", is_table(make_crontab(crontab_data)))
end)

test:case "simple hash" (function()
  local crontab_data =
  {
    {
      s    = "*";
      m    = "*";
      h    = "*";
      dom  = "*";
      mon  = "*";
      dow  = "*";
      data = CRON_DATA;
    }
  }
  ensure("crontab", is_table(make_crontab(crontab_data)))
end)

--------------------------------------------------------------------------------

test:group "make_cron_properties"
-- Note: make_cron_properties also tested implicitly in 
-- make_next_occurrence_getter tests

do
  local check_cron_defs_equal = function(exp1, exp2)
    arguments(
        "string", exp1,
        "string", exp2
      )
    local cron_props1 = assert(make_cron_properties(
        make_raw_cron_data_from_string(exp1, CRON_DATA)
      ))
    local cron_props2 = assert(make_cron_properties(
        make_raw_cron_data_from_string(exp2, CRON_DATA)
      ))
    ensure_tdeepequals(
        "equal definitions of cron",
        cron_props1,
        cron_props2
      )
  end

  -- Test two cron definitions are equivalent
  -- format: cron_expression1, cron_expression2
  local equivalent_cron_defs_data =
  {
    ["simple"] =
    {
      {          "* * 1-3 * * *",                 "* * 1-2,3 * * *" };
      {          "* * 1-3 * * *",                 "* * 1,2-3 * * *" };
      {          "* * 1-3 * * *",                 "* * 1,2,3 * * *" };
      { "* * * * 1,3,5,7,9,11 *",                   "* * * * */2 *" };
      {     "* 10,25,40 * * * *",              "* 10-40/15 * * * *" };
      {    "* * * * 1,3,8 0,1-2,5", "* * * * Mar,Jan,Aug Fri,Mon-Tue,Sun" };
    };

    ["guffy-day-of-week-names"] =
    {
      {
        "* 20 * * * 0,1,2,3,4,5,6",
        "* 20 * * * Sun,Mon,Tue,Wed,Thu,Fri,Sat"
      };
      {
        "* 20 * * * 0,1,2,3,4,5,6",
        "* 20 * * * Sunday,Monday,Tuesday,Wednesday,Thursday,Friday,Saturday"
      };
    };

    ["guffy-month-names"] = {
      {
        "* 20 * * 1,2,3,4,5,6,7,8,9,10,11,12 *",
        "* 20 * * Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec *"
      };
      {
        "* 20 * * 1,2,3,4,5,6,7,8,9,10,11,12 *",
        "* 20 * * January,February,March,April,May,June,July,August,September,"
          .. "October,November,December *"
      };
    };

    ["repeated"] =
    {
      { "*/10 * * * * *", "0,10,20,30,40,50 * * * * *" };
      { "*/25 * * * * *", "0,25,50 * * * * *" };
      { "5/10 * * * * *", "5,15,25,35,45,55 * * * * *" };
      { "5/25 * * * * *", "5,30,55 * * * * *" };
      { "10-40/10 * * * * *", "10,20,30,40 * * * * *" };
      { "10-40/25 * * * * *", "10,35 * * * * *" };

      { "* */10 * * * *", "* 0,10,20,30,40,50 * * * *" };
      { "* */25 * * * *", "* 0,25,50 * * * *" };
      { "* 5/10 * * * *", "* 5,15,25,35,45,55 * * * *" };
      { "* 5/25 * * * *", "* 5,30,55 * * * *" };
      { "* 10-40/10 * * * *", "* 10,20,30,40 * * * *" };
      { "* 10-40/25 * * * *", "* 10,35 * * * *" };

      { "* * */10 * * *", "* * 0,10,20 * * *" };
      { "* * */8 * * *", "* * 0,8,16 * * *" };
      { "* * 5/10 * * *", "* * 5,15 * * *" };
      { "* * 5/20 * * *", "* * 5 * * *" };
      { "* * 2-23/8 * * *", "* * 2,10,18 * * *" };
      { "* * 2-23/23 * * *", "* * 2 * * *" };

      { "* * * */10 * *", "* * * 1,11,21 * *" };
      { "* * * */8 * *", "* * * 1,9,17,25 * *" };
      { "* * * 5/10 * *", "* * * 5,15,25 * *" };
      { "* * * 5/20 * *", "* * * 5,25 * *" };
      { "* * * 2-23/8 * *", "* * * 2,10,18 * *" };
      { "* * * 2-23/23 * *", "* * * 2 * *" };

      { "* * * * */3 *", "* * * * 1,4,7,10 *" };
      { "* * * * */8 *", "* * * * 1,9 *" };
      { "* * * * 5/3 *", "* * * * 2,5,8,11 *" };
      { "* * * * May/3 *", "* * * * 2,5,8,11 *" };
      { "* * * * 5/11 *", "* * * * 5 *" };
      { "* * * * May/11 *", "* * * * 5 *" };
      { "* * * * 2-11/4 *", "* * * * 2,6,10 *" };
      { "* * * * 2-11/12 *", "* * * * 2 *" };
      { "* * * * Feb-Nov/4 *", "* * * * 2,6,10 *" };
      { "* * * * Feb-Nov/12 *", "* * * * 2 *" };
      { "* * * * Feb-Nov/4 *", "* * * * Feb,Jun,Oct *" };
      { "* * * * Feb-Nov/12 *", "* * * * Feb *" };

      { "* * * * * */3", "* * * * * 0,3,6" };
      { "* * * * * */6", "* * * * * 0,6" };
      { "* * * * * 1/2", "* * * * * 1,3,5" };
      { "* * * * * Mon/2", "* * * * * 1,3,5" };
      { "* * * * * 1-5/2", "* * * * * 1,3,5" };
      { "* * * * * 1-5/6", "* * * * * 1" };
      { "* * * * * Mon-Fri/4", "* * * * * 1,5" };
      { "* * * * * Mon-Fri/5", "* * * * * 1" };
    };
  };

  run_tests(
      "make_cron_properties",
      equivalent_cron_defs_data,
      check_cron_defs_equal
    )
end
--
test:case "invalid-days" (function()
  ensure_fails_with_substring(
      "May,0",
      function()
        make_cron_properties({ "*", "*", "*", "0", "May", "*", CRON_DATA })
      end,
      "too small value: 0"
    )
  ensure_fails_with_substring(
      "May,32",
      function()
        make_cron_properties({ "*", "*", "*", "32", "May", "*", CRON_DATA })
      end,
      "too big value: 32"
    )
  ensure_fails_with_substring(
      "25:mm:ss",
      function()
        make_cron_properties({ "*", "*", "25", "*", "*", "*", CRON_DATA })
      end,
      "too big value: 25"
    )
  ensure_fails_with_substring(
      "hh:61:ss",
      function()
        make_cron_properties({ "*", "61", "*", "*", "*", "*", CRON_DATA })
      end,
      "too big value: 61"
    )
  ensure_fails_with_substring(
      "hh:mm:61",
      function()
        make_cron_properties({ "61", "*", "*", "*", "*", "*", CRON_DATA })
      end,
      "too big value: 61"
    )
end)

--------------------------------------------------------------------------------

test:group "make_next_occurrence_getter"

do
  local check_cron_occurence = function(
      start_time,
      raw_cron_data,
      expected_cron_time,
      expected_err
    )
    arguments(
        "string", start_time
      )
    optional_arguments(
        "string", expected_err
      )

    if is_string(raw_cron_data) then
      local as_hash = nil -- may be false or true also
      raw_cron_data = assert_is_table(make_raw_cron_data_from_string(
          raw_cron_data, CRON_DATA, as_hash
        ))
    else
      assert_is_table(raw_cron_data)
    end

    local cron_properties = assert(make_cron_properties(raw_cron_data))
    local nog = assert(make_next_occurrence_getter(cron_properties))

    local next_occurrence =
      nog:get_next_occurrence(make_timestamp_from_string(start_time))

    if expected_cron_time == false then
      ensure_equals("next occurrence", next_occurrence, false)
    else
      ensure_strequals(
          "next occurrence",
          os.date("%c", next_occurrence),
          os.date("%c", make_timestamp_from_string(expected_cron_time))
        )
    end
  end

  -- Test cron occur in right time
  -- format: start_time, cron, expected_cron_time
  local check_cron_occurence_data =
  {
    ["simple"] =
    {
      { "01.01.2003 00:00:00", "* * * * * *", "01.01.2003 00:00:01" };
      { "01.01.2003 00:00:11", "* * * * * *", "01.01.2003 00:00:12" };
      { "01.01.2003 00:01:59", "* * * * * *", "01.01.2003 00:02:00" };
      { "01.01.2003 00:02:59", "* * * * * *", "01.01.2003 00:03:00" };
      { "01.01.2003 00:59:59", "* * * * * *", "01.01.2003 01:00:00" };
      { "01.01.2003 01:59:59", "* * * * * *", "01.01.2003 02:00:00" };
      { "01.01.2003 23:59:59", "* * * * * *", "02.01.2003 00:00:00" };
      { "31.12.2003 23:59:59", "* * * * * *", "01.01.2004 00:00:00" };

      { "28.02.2003 23:59:59", "* * * * * *", "01.03.2003 00:00:00" };
      { "28.02.2004 23:59:59", "* * * * * *", "29.02.2004 00:00:00" };
    };

    ["numeric_fields"] = -- Test for numeric (not string) field values
    {
      { -- second
        "01.01.2003 00:00:00",
        { 45, "*", "*", "*", "*", "*", CRON_DATA },
        "01.01.2003 00:00:45"
      };
      { -- minute
        "01.01.2003 00:00:00",
        { "*", 45, "*", "*", "*", "*", CRON_DATA },
        "01.01.2003 00:45:00"
      };
      { -- hour
        "20.12.2003 00:30:00",
        { "*", "*", 3, "*", "*", "*", CRON_DATA },
        "20.12.2003 03:00:00"
      };
      { -- day of month
        "07.01.2003 00:00:00",
        { "*", "30", "*", 1, "*", "*", CRON_DATA },
        "01.02.2003 00:30:00"
      };
      { -- month
        "28.02.2002 23:59:59",
        { "*", "*", "*", "*", 3, "*", CRON_DATA },
        "01.03.2002 00:00:00"
      };
      { -- day of week
        "19.06.2003 00:00:00",
        { "1", "1", "12", "*", "*", 2, CRON_DATA },
        "24.06.2003 12:01:01"
      };
    };

    ["second"] = -- Second tests
    {
      { "01.01.2003 00:00:00", "45 * * * * *", "01.01.2003 00:00:45" };
      { "01.01.2003 00:00:00", "45-47,48,49 * * * * *", "01.01.2003 00:00:45" };
      { "01.01.2003 00:00:45", "45-47,48,49 * * * * *", "01.01.2003 00:00:46" };
      { "01.01.2003 00:00:46", "45-47,48,49 * * * * *", "01.01.2003 00:00:47" };
      { "01.01.2003 00:00:47", "45-47,48,49 * * * * *", "01.01.2003 00:00:48" };
      { "01.01.2003 00:00:48", "45-47,48,49 * * * * *", "01.01.2003 00:00:49" };
      { "01.01.2003 00:00:49", "45-47,48,49 * * * * *", "01.01.2003 00:01:45" };
    };

    ["minute"] = -- Minute tests
    {
      { "01.01.2003 00:00:00", "* 45 * * * *", "01.01.2003 00:45:00" };
      { "01.01.2003 00:00:00", "* 45-47,48,49 * * * *", "01.01.2003 00:45:00" };
      { "01.01.2003 00:45:59", "* 45-47,48,49 * * * *", "01.01.2003 00:46:00" };
      { "01.01.2003 00:46:59", "* 45-47,48,49 * * * *", "01.01.2003 00:47:00" };
      { "01.01.2003 00:47:59", "* 45-47,48,49 * * * *", "01.01.2003 00:48:00" };
      { "01.01.2003 00:48:59", "* 45-47,48,49 * * * *", "01.01.2003 00:49:00" };
      { "01.01.2003 00:49:59", "* 45-47,48,49 * * * *", "01.01.2003 01:45:00" };

      { "01.01.2003 00:00:00", "* 2/5 * * * *", "01.01.2003 00:02:00" };
      { "01.01.2003 00:02:00", "* 2/5 * * * *", "01.01.2003 00:02:01" };
      { "01.01.2003 00:02:00", "0 2/5 * * * *", "01.01.2003 00:07:00" };
      { "01.01.2003 00:50:00", "* 2/5 * * * *", "01.01.2003 00:52:00" };
      { "01.01.2003 00:52:00", "* 2/5 * * * *", "01.01.2003 00:52:01" };
      { "01.01.2003 00:52:00", "0 2/5 * * * *", "01.01.2003 00:57:00" };
      { "01.01.2003 00:57:00", "* 2/5 * * * *", "01.01.2003 00:57:01" };
      { "01.01.2003 00:57:00", "0 2/5 * * * *", "01.01.2003 01:02:00" };
    };

    ["hour"] = -- Hour tests
    {
      { "20.12.2003 10:00:00", "*  * 3/4 * * *", "20.12.2003 11:00:00" };
      { "20.12.2003 00:30:00", "*  * 3   * * *", "20.12.2003 03:00:00" };
      { "20.12.2003 01:45:00", "* 30 3   * * *", "20.12.2003 03:30:00" };
    };

    ["day-of-month"] = -- Day of month tests
    {
      { "07.01.2003 00:00:00", "* 30  *  1 * *", "01.02.2003 00:30:00" };
      { "01.02.2003 00:30:59", "* 30  *  1 * *", "01.02.2003 01:30:00" };

      { "01.01.2003 00:00:00", "* 10  * 22    * *", "22.01.2003 00:10:00" };
      { "01.01.2003 00:00:00", "* 30 23 19    * *", "19.01.2003 23:30:00" };
      { "01.01.2003 00:00:00", "* 30 23 21    * *", "21.01.2003 23:30:00" };
      { "01.01.2003 00:01:00", "*  *  * 21    * *", "21.01.2003 00:00:00" };
      { "10.07.2003 00:00:00", "*  *  * 30,31 * *", "30.07.2003 00:00:00" };
    };

    -- Test month rollovers for months with 28,29,30 and 31 days
    ["month-rollover"] =
    {
      { "28.02.2002 23:59:59", "* * * * 3 *", "01.03.2002 00:00:00" };
      { "29.02.2004 23:59:59", "* * * * 3 *", "01.03.2004 00:00:00" };
      { "31.03.2002 23:59:59", "* * * * 4 *", "01.04.2002 00:00:00" };
      { "30.04.2002 23:59:59", "* * * * 5 *", "01.05.2002 00:00:00" };
    };

    ["month-30,31"] = -- Test month 30,31 days
    {
      { "01.01.2000 00:00:00", "0 0 0 15,30,31 * *", "15.01.2000 00:00:00" };
      { "15.01.2000 00:00:00", "0 0 0 15,30,31 * *", "30.01.2000 00:00:00" };
      { "30.01.2000 00:00:00", "0 0 0 15,30,31 * *", "31.01.2000 00:00:00" };
      { "31.01.2000 00:00:00", "0 0 0 15,30,31 * *", "15.02.2000 00:00:00" };

      { "15.02.2000 00:00:00", "0 0 0 15,30,31 * *", "15.03.2000 00:00:00" };

      { "15.03.2000 00:00:00", "0 0 0 15,30,31 * *", "30.03.2000 00:00:00" };
      { "30.03.2000 00:00:00", "0 0 0 15,30,31 * *", "31.03.2000 00:00:00" };
      { "31.03.2000 00:00:00", "0 0 0 15,30,31 * *", "15.04.2000 00:00:00" };

      { "15.04.2000 00:00:00", "0 0 0 15,30,31 * *", "30.04.2000 00:00:00" };
      { "30.04.2000 00:00:00", "0 0 0 15,30,31 * *", "15.05.2000 00:00:00" };

      { "15.05.2000 00:00:00", "0 0 0 15,30,31 * *", "30.05.2000 00:00:00" };
      { "30.05.2000 00:00:00", "0 0 0 15,30,31 * *", "31.05.2000 00:00:00" };
      { "31.05.2000 00:00:00", "0 0 0 15,30,31 * *", "15.06.2000 00:00:00" };

      { "15.06.2000 00:00:00", "0 0 0 15,30,31 * *", "30.06.2000 00:00:00" };
      { "30.06.2000 00:00:00", "0 0 0 15,30,31 * *", "15.07.2000 00:00:00" };

      { "15.07.2000 00:00:00", "0 0 0 15,30,31 * *", "30.07.2000 00:00:00" };
      { "30.07.2000 00:00:00", "0 0 0 15,30,31 * *", "31.07.2000 00:00:00" };
      { "31.07.2000 00:00:00", "0 0 0 15,30,31 * *", "15.08.2000 00:00:00" };

      { "15.08.2000 00:00:00", "0 0 0 15,30,31 * *", "30.08.2000 00:00:00" };
      { "30.08.2000 00:00:00", "0 0 0 15,30,31 * *", "31.08.2000 00:00:00" };
      { "31.08.2000 00:00:00", "0 0 0 15,30,31 * *", "15.09.2000 00:00:00" };

      { "15.09.2000 00:00:00", "0 0 0 15,30,31 * *", "30.09.2000 00:00:00" };
      { "30.09.2000 00:00:00", "0 0 0 15,30,31 * *", "15.10.2000 00:00:00" };

      { "15.10.2000 00:00:00", "0 0 0 15,30,31 * *", "30.10.2000 00:00:00" };
      { "30.10.2000 00:00:00", "0 0 0 15,30,31 * *", "31.10.2000 00:00:00" };
      { "31.10.2000 00:00:00", "0 0 0 15,30,31 * *", "15.11.2000 00:00:00" };

      { "15.11.2000 00:00:00", "0 0 0 15,30,31 * *", "30.11.2000 00:00:00" };
      { "30.11.2000 00:00:00", "0 0 0 15,30,31 * *", "15.12.2000 00:00:00" };

      { "15.12.2000 00:00:00", "0 0 0 15,30,31 * *", "30.12.2000 00:00:00" };
      { "30.12.2000 00:00:00", "0 0 0 15,30,31 * *", "31.12.2000 00:00:00" };
      { "31.12.2000 00:00:00", "0 0 0 15,30,31 * *", "15.01.2001 00:00:00" };
    };

    ["month-other"] = -- Other month tests (including year rollover)
    {
      { "01.12.2003 05:00:00", "15 10 * * 6 *", "01.06.2004 00:10:15" };
      { "04.01.2003 05:00:00", "1 2 3 4 * *", "04.02.2003 03:02:01" };
      {
        "01.07.2002 05:00:00",
        "15 10 * * February,April-June *",
        "01.02.2003 00:10:15"
      };
      {
        "01.05.2002 05:00:00",
        "15 10 * * February,April-June *",
        "01.05.2002 05:10:15" };
      {
        "01.05.2002 05:00:00",
        "15 10 * * February,April,June *",
        "01.06.2002 00:10:15"
      };
      { "01.01.2003 00:00:00", "0 0 12 1 6 *", "01.06.2003 12:00:00" };
      { "11.09.1988 14:23:00", "* * 12 1 6 *", "01.06.1989 12:00:00" };
      { "11.03.1988 14:23:00", "* * 12 1 6 *", "01.06.1988 12:00:00" };
      { "11.03.1988 14:23:00", "* * 2,4-8,15 * 6 *", "01.06.1988 02:00:00" };

      {
        "11.03.1988 14:23:00",
        "* 20 * * Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec *",
        "11.03.1988 15:20:00"
      };
    };

    ["day-of-week"] = -- Day of week tests
    {
      { "26.06.2003 10:00:00", "10 30 6 * * 0",      "29.06.2003 06:30:10" };
      { "26.06.2003 10:00:00", "10 30 6 * * Sunday", "29.06.2003 06:30:10" };
      { "19.06.2003 00:00:00", "1 1 12 * * 2",      "24.06.2003 12:01:01" };
      { "24.06.2003 12:01:01", "1 1 12 * * 2",      "01.07.2003 12:01:01" };
      { "01.06.2003 14:55:23", "10 15 18 * * Mon", "02.06.2003 18:15:10" };
      { "02.06.2003 18:15:10", "10 15 18 * * Mon", "09.06.2003 18:15:10" };
      { "09.06.2003 18:15:10", "10 15 18 * * Mon", "16.06.2003 18:15:10" };
      { "16.06.2003 18:15:10", "10 15 18 * * Mon", "23.06.2003 18:15:10" };
      { "23.06.2003 18:15:10", "10 15 18 * * Mon", "30.06.2003 18:15:10" };
      { "30.06.2003 18:15:10", "10 15 18 * * Mon", "07.07.2003 18:15:10" };

      { "01.01.2003 00:00:00", "* * * * * Mon",   "06.01.2003 00:00:00" };
      { "01.01.2003 12:00:00", "* 45 16 1 * Mon", "01.09.2003 16:45:00" };
      { "01.09.2003 23:45:00", "* 45 16 1 * Mon", "01.12.2003 16:45:00" };
    };

    ["leap-years"] = -- Leap year tests
    {
      { "01.01.2000 12:00:00", "1 1 12 29 2 *", "29.02.2000 12:01:01" };
      { "29.02.2000 12:01:01", "1 1 12 29 2 *", "29.02.2004 12:01:01" };
      { "29.02.2004 12:01:01", "1 1 12 29 2 *", "29.02.2008 12:01:01" };
    };

    ["non-leap-years"] = -- Non-leap year tests
    {
      { "01.01.2000 12:00:00", "1 1 12 28 2 *", "28.02.2000 12:01:01" };
      { "28.02.2000 12:01:01", "1 1 12 28 2 *", "28.02.2001 12:01:01" };
      { "28.02.2001 12:01:01", "1 1 12 28 2 *", "28.02.2002 12:01:01" };
      { "28.02.2002 12:01:01", "1 1 12 28 2 *", "28.02.2003 12:01:01" };
      { "28.02.2003 12:01:01", "1 1 12 28 2 *", "28.02.2004 12:01:01" };
      { "29.02.2004 12:01:01", "1 1 12 28 2 *", "28.02.2005 12:01:01" };
    };

    ["non-existing-dates"] = -- Non-leap year tests
    {
      { "01.01.2003 00:00:00", "* * * 30 feb *", false };
      { "01.01.2003 00:00:00", "* * * 31 apr *", false };
    };

    ["repeated"] =
    {
      { "01.01.2005 00:00:00", "*/1 * * * * *", "01.01.2005 00:00:01" };
      { "01.01.2005 00:00:00", "*/2 * * * * *", "01.01.2005 00:00:02" };
      { "01.01.2005 00:00:01", "1/2 * * * * *", "01.01.2005 00:00:03" };

      { "01.01.2005 00:00:03", "1/2 * * * * *", "01.01.2005 00:00:05" };
      { "01.01.2005 00:00:04", "1/2 * * * * *", "01.01.2005 00:00:05" };
      { "01.01.2005 00:00:04", "5/2 * * * * *", "01.01.2005 00:00:05" };
      { "01.01.2005 00:00:01", "59/2 * * * * *", "01.01.2005 00:00:03" };
      { "01.01.2005 00:00:01", "59/59 * * * * *", "01.01.2005 00:00:59" };
      { "01.01.2005 00:00:59", "59/59 * * * * *", "01.01.2005 00:01:00" };
      { "01.01.2005 00:01:00", "59/59 * * * * *", "01.01.2005 00:01:59" };
      { "01.01.2005 00:00:00", "20-30/3 * * * * *", "01.01.2005 00:00:20" };
      { "01.01.2005 00:00:20", "20-30/3 * * * * *", "01.01.2005 00:00:23" };
      { "01.01.2005 00:00:23", "20-30/3 * * * * *", "01.01.2005 00:00:26" };
      { "01.01.2005 00:00:26", "20-30/3 * * * * *", "01.01.2005 00:00:29" };
      { "01.01.2005 00:00:29", "20-30/3 * * * * *", "01.01.2005 00:01:20" };
      { "01.01.2005 00:00:39", "20-30/3 * * * * *", "01.01.2005 00:01:20" };

      { "01.01.2005 00:03:00", "* 1/2 * * * *", "01.01.2005 00:03:01" };
      { "01.01.2005 00:04:00", "* 1/2 * * * *", "01.01.2005 00:05:00" };
      { "01.01.2005 00:04:00", "* 5/2 * * * *", "01.01.2005 00:05:00" };
      { "01.01.2005 00:01:00", "* 59/2 * * * *", "01.01.2005 00:01:01" };
      { "01.01.2005 00:01:00", "* 59/59 * * * *", "01.01.2005 00:59:00" };
      { "01.01.2005 00:59:00", "* 59/59 * * * *", "01.01.2005 00:59:01" };
      { "01.01.2005 01:00:00", "* 59/59 * * * *", "01.01.2005 01:00:01" };
      { "01.01.2005 00:00:00", "* 20-30/3 * * * *", "01.01.2005 00:20:00" };
      { "01.01.2005 00:20:00", "* 20-30/3 * * * *", "01.01.2005 00:20:01" };
      { "01.01.2005 00:23:00", "* 20-30/3 * * * *", "01.01.2005 00:23:01" };
      { "01.01.2005 00:26:00", "* 20-30/3 * * * *", "01.01.2005 00:26:01" };
      { "01.01.2005 00:29:00", "* 20-30/3 * * * *", "01.01.2005 00:29:01" };
      { "01.01.2005 00:39:00", "* 20-30/3 * * * *", "01.01.2005 01:20:00" };

      { "01.01.2005 00:03:00", "7 1/2 * * * *", "01.01.2005 00:03:07" };
      { "01.01.2005 00:03:07", "7 1/2 * * * *", "01.01.2005 00:05:07" };
      { "01.01.2005 00:04:00", "7 1/2 * * * *", "01.01.2005 00:05:07" };
      { "01.01.2005 00:04:00", "7 5/2 * * * *", "01.01.2005 00:05:07" };
      { "01.01.2005 00:01:07", "7 59/2 * * * *", "01.01.2005 00:03:07" };
      { "01.01.2005 00:01:07", "7 59/59 * * * *", "01.01.2005 00:59:07" };
      { "01.01.2005 00:59:07", "7 59/59 * * * *", "01.01.2005 01:00:07" };
      { "01.01.2005 01:00:07", "7 59/59 * * * *", "01.01.2005 01:59:07" };
      { "01.01.2005 00:00:00", "7 20-30/3 * * * *", "01.01.2005 00:20:07" };
      { "01.01.2005 00:20:07", "7 20-30/3 * * * *", "01.01.2005 00:23:07" };
      { "01.01.2005 00:23:07", "7 20-30/3 * * * *", "01.01.2005 00:26:07" };
      { "01.01.2005 00:26:07", "7 20-30/3 * * * *", "01.01.2005 00:29:07" };
      { "01.01.2005 00:29:07", "7 20-30/3 * * * *", "01.01.2005 01:20:07" };
      { "01.01.2005 00:39:00", "7 20-30/3 * * * *", "01.01.2005 01:20:07" };

      { "01.01.2005 03:00:00", "* * 1/2 * * *", "01.01.2005 03:00:01" };
      { "01.01.2005 04:00:00", "* * 1/2 * * *", "01.01.2005 05:00:00" };
      { "01.01.2005 04:00:00", "* * 5/2 * * *", "01.01.2005 05:00:00" };
      { "01.01.2005 01:00:00", "* * 23/2 * * *", "01.01.2005 01:00:01" };
      { "01.01.2005 01:00:00", "* * 23/23 * * *", "01.01.2005 23:00:00" };
      { "01.01.2005 23:00:00", "* * 23/23 * * *", "01.01.2005 23:00:01" };
      { "02.01.2005 00:00:00", "* * 23/23 * * *", "02.01.2005 00:00:01" };
      { "01.01.2005 00:00:00", "* * 9-19/3 * * *", "01.01.2005 09:00:00" };
      { "01.01.2005 09:00:00", "* * 9-19/3 * * *", "01.01.2005 09:00:01" };
      { "01.01.2005 12:00:00", "* * 9-19/3 * * *", "01.01.2005 12:00:01" };
      { "01.01.2005 15:00:00", "* * 9-19/3 * * *", "01.01.2005 15:00:01" };
      { "01.01.2005 18:00:00", "* * 9-19/3 * * *", "01.01.2005 18:00:01" };
      { "01.01.2005 23:00:00", "* * 9-19/3 * * *", "02.01.2005 09:00:00" };

      { "01.01.2005 03:00:00", "0 0 1/2 * * *", "01.01.2005 05:00:00" };
      { "01.01.2005 04:00:00", "0 0 1/2 * * *", "01.01.2005 05:00:00" };
      { "01.01.2005 04:00:00", "0 0 5/2 * * *", "01.01.2005 05:00:00" };
      { "01.01.2005 01:00:00", "0 0 23/2 * * *", "01.01.2005 03:00:00" };
      { "01.01.2005 01:00:00", "0 0 23/23 * * *", "01.01.2005 23:00:00" };
      { "01.01.2005 23:00:00", "0 0 23/23 * * *", "02.01.2005 00:00:00" };
      { "02.01.2005 00:00:00", "0 0 23/23 * * *", "02.01.2005 23:00:00" };
      { "01.01.2005 00:00:00", "0 0 9-19/3 * * *", "01.01.2005 09:00:00" };
      { "01.01.2005 09:00:00", "0 0 9-19/3 * * *", "01.01.2005 12:00:00" };
      { "01.01.2005 12:00:00", "0 0 9-19/3 * * *", "01.01.2005 15:00:00" };
      { "01.01.2005 15:00:00", "0 0 9-19/3 * * *", "01.01.2005 18:00:00" };
      { "01.01.2005 18:00:00", "0 0 9-19/3 * * *", "02.01.2005 09:00:00" };
      { "01.01.2005 23:00:00", "0 0 9-19/3 * * *", "02.01.2005 09:00:00" };

      { "03.01.2005 00:00:00", "* * * 1/2 * *", "03.01.2005 00:00:01" };
      { "04.01.2005 00:00:00", "* * * 1/2 * *", "05.01.2005 00:00:00" };
      { "04.01.2005 00:00:00", "* * * 5/2 * *", "05.01.2005 00:00:00" };
      { "02.01.2005 00:00:00", "* * * 23/2 * *", "03.01.2005 00:00:00" };
      { "02.01.2005 00:00:00", "* * * 23/23 * *", "23.01.2005 00:00:00" };
      { "23.01.2005 00:00:00", "* * * 23/23 * *", "23.01.2005 00:00:01" };
      { "23.02.2005 00:00:00", "* * * 23/23 * *", "23.02.2005 00:00:01" };
      { "01.01.2005 00:00:00", "* * * 9-19/3 * *", "09.01.2005 00:00:00" };
      { "09.01.2005 00:00:00", "* * * 9-19/3 * *", "09.01.2005 00:00:01" };
      { "12.01.2005 00:00:00", "* * * 9-19/3 * *", "12.01.2005 00:00:01" };
      { "15.01.2005 00:00:00", "* * * 9-19/3 * *", "15.01.2005 00:00:01" };
      { "18.01.2005 00:00:00", "* * * 9-19/3 * *", "18.01.2005 00:00:01" };
      { "23.01.2005 00:00:00", "* * * 9-19/3 * *", "09.02.2005 00:00:00" };

      { "03.01.2005 00:00:00", "0 0 0 1/2 * *", "05.01.2005 00:00:00" };
      { "04.01.2005 00:00:00", "0 0 0 1/2 * *", "05.01.2005 00:00:00" };
      { "04.01.2005 00:00:00", "0 0 0 5/2 * *", "05.01.2005 00:00:00" };
      { "02.01.2005 00:00:00", "0 0 0 23/2 * *", "03.01.2005 00:00:00" };
      { "02.01.2005 00:00:00", "0 0 0 23/23 * *", "23.01.2005 00:00:00" };
      { "23.01.2005 00:00:00", "0 0 0 23/22 * *", "01.02.2005 00:00:00" };
      { "23.02.2005 00:00:00", "0 0 0 23/22 * *", "01.03.2005 00:00:00" };
      { "01.01.2005 00:00:00", "0 0 0 9-19/3 * *", "09.01.2005 00:00:00" };
      { "09.01.2005 00:00:00", "0 0 0 9-19/3 * *", "12.01.2005 00:00:00" };
      { "12.01.2005 00:00:00", "0 0 0 9-19/3 * *", "15.01.2005 00:00:00" };
      { "15.01.2005 00:00:00", "0 0 0 9-19/3 * *", "18.01.2005 00:00:00" };
      { "18.01.2005 00:00:00", "0 0 0 9-19/3 * *", "09.02.2005 00:00:00" };
      { "23.01.2005 00:00:00", "0 0 0 9-19/3 * *", "09.02.2005 00:00:00" };

      { "27.02.2020 00:00:00", "0 0 0 */2 * *", "29.02.2020 00:00:00" };
      { "27.02.2019 00:00:00", "0 0 0 */2 * *", "01.03.2019 00:00:00" };
      { "27.03.2019 00:00:00", "0 0 0 */2 * *", "29.03.2019 00:00:00" };

      { "01.03.2005 00:00:00", "* * * * 1/2 *", "01.03.2005 00:00:01" };
      { "01.03.2005 00:00:00", "* * * * Jan/2 *", "01.03.2005 00:00:01" };
      { "01.04.2005 00:00:00", "* * * * 1/2 *", "01.05.2005 00:00:00" };
      { "01.04.2005 00:00:00", "* * * * 5/2 *", "01.05.2005 00:00:00" };
      { "01.02.2005 00:00:00", "* * * * 11/2 *", "01.03.2005 00:00:00" };
      { "01.02.2005 00:00:00", "* * * * Nov/2 *", "01.03.2005 00:00:00" };
      { "01.02.2005 00:00:00", "* * * * 11/11 *", "01.11.2005 00:00:00" };
      { "01.08.2005 00:00:00", "* * * * 11/10 *", "01.11.2005 00:00:00" };
      { "01.11.2005 00:00:00", "* * * * 11/10 *", "01.11.2005 00:00:01" };
      { "01.01.2005 00:00:00", "* * * * 4-11/3 *", "01.04.2005 00:00:00" };
      { "01.04.2005 00:00:00", "* * * * 4-11/3 *", "01.04.2005 00:00:01" };
      { "01.07.2005 00:00:00", "* * * * 4-11/3 *", "01.07.2005 00:00:01" };
      { "01.07.2005 00:00:00", "* * * * Apr-Nov/3 *", "01.07.2005 00:00:01" };
      { "01.10.2005 00:00:00", "* * * * 4-11/3 *", "01.10.2005 00:00:01" };
      { "01.12.2005 00:00:00", "* * * * 4-11/3 *", "01.04.2006 00:00:00" };

      { "01.03.2005 00:00:00", "0 0 0 1 1/2 *", "01.05.2005 00:00:00" };
      { "01.03.2005 00:00:00", "0 0 0 1 Jan/2 *", "01.05.2005 00:00:00" };
      { "01.04.2005 00:00:00", "0 0 0 1 1/2 *", "01.05.2005 00:00:00" };
      { "01.04.2005 00:00:00", "0 0 0 1 5/2 *", "01.05.2005 00:00:00" };
      { "01.02.2005 00:00:00", "0 0 0 1 11/2 *", "01.03.2005 00:00:00" };
      { "01.02.2005 00:00:00", "0 0 0 1 Nov/2 *", "01.03.2005 00:00:00" };
      { "01.02.2005 00:00:00", "0 0 0 1 11/11 *", "01.11.2005 00:00:00" };
      { "01.08.2005 00:00:00", "0 0 0 1 11/10 *", "01.11.2005 00:00:00" };
      { "01.11.2005 00:00:00", "0 0 0 1 11/10 *", "01.01.2006 00:00:00" };
      { "01.01.2005 00:00:00", "0 0 0 1 4-11/3 *", "01.04.2005 00:00:00" };
      { "01.04.2005 00:00:00", "0 0 0 1 4-11/3 *", "01.07.2005 00:00:00" };
      { "01.07.2005 00:00:00", "0 0 0 1 4-11/3 *", "01.10.2005 00:00:00" };
      { "01.07.2005 00:00:00", "0 0 0 1 Apr-Nov/3 *", "01.10.2005 00:00:00" };
      { "01.10.2005 00:00:00", "0 0 0 1 4-11/3 *", "01.04.2006 00:00:00" };
      { "01.12.2005 00:00:00", "0 0 0 1 4-11/3 *", "01.04.2006 00:00:00" };

      { "02.03.2005 00:00:00", "* * * * * 1/2", "02.03.2005 00:00:01" };
      { "02.03.2005 00:00:00", "* * * * * Mon/2", "02.03.2005 00:00:01" };
      { "01.03.2005 00:00:00", "* * * * * 1/2", "02.03.2005 00:00:00" };
      { "01.03.2005 00:00:00", "* * * * * 5/2", "02.03.2005 00:00:00" };
      { "01.03.2005 00:00:00", "* * * * * 6/2", "01.03.2005 00:00:01" };
      { "01.03.2005 00:00:00", "* * * * * Sat/2", "01.03.2005 00:00:01" };
      { "02.03.2005 00:00:00", "* * * * * 6/6", "05.03.2005 00:00:00" };
      { "27.02.2005 00:00:00", "* * * * * 6/6", "27.02.2005 00:00:01" };
      { "06.03.2005 00:00:00", "* * * * * 6/6", "06.03.2005 00:00:01" };
      { "01.03.2005 00:00:00", "* * * * * 1-5/2", "02.03.2005 00:00:00" };
      { "02.03.2005 00:00:00", "* * * * * 1-5/2", "02.03.2005 00:00:01" };
      { "03.03.2005 00:00:00", "* * * * * 1-5/2", "04.03.2005 00:00:00" };
      { "04.03.2005 00:00:00", "* * * * * 1-5/2", "04.03.2005 00:00:01" };
      { "05.03.2005 00:00:00", "* * * * * 1-5/2", "07.03.2005 00:00:00" };
      { "05.03.2005 00:00:00", "* * * * * Mon-Fri/2", "07.03.2005 00:00:00" };
    };
  }

  run_tests(
      "make_next_occurrence_getter",
      check_cron_occurence_data,
      check_cron_occurence
    )
end

--------------------------------------------------------------------------------

-- Do we need to test it actually? It is tested implicitly
test:UNTESTED "make_raw_cron_data_from_string"

--------------------------------------------------------------------------------

-- TODO: Implement next tests
--[=[
  -- check cron processing will end
  local check_cron_will_end = -- format: cron, start_time, end_time
  {
    { "*  *  * * * *  ", "01.01.2003 00:00:00", "01.01.2003 00:00:00" };
    { "*  *  * * * *  ", "31.12.2002 23:59:00", "01.01.2003 00:00:00" };
    { "*  *  * * * Mon", "31.12.2002 23:59:00", "01.01.2003 00:00:00" };
    { "*  *  * * * Mon", "01.01.2003 00:00:00", "02.01.2003 00:00:00" };
    { "*  *  * * * Mon", "01.01.2003 00:00:00", "02.01.2003 12:00:00" };
    { "* 30 12 * * Mon", "01.01.2003 00:00:00", "06.01.2003 12:00:00" };
  }
]=]