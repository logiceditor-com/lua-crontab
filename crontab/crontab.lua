--------------------------------------------------------------------------------
-- <pre>
-- crontab.lua: stores crons, determines next occurrence of cron
-- This file is a part of lua-crontab library
-- Copyright (c) 2010-2021 lua-crontab authors
-- See file `COPYRIGHT` for the license
-- </pre>
--
-- <pre>
-- Crontab format ("hash"):
--
-- {
--   s    = "*";
--   m    = "*";
--   h    = "*";
--   dom  = "*";
--   mon  = "*";
--   dow  = "*";
--   data = any;
-- }
--
-- Alternative crontab format ("array"):
--
-- "*","*","*","*","*","*", data
--  ^   ^   ^   ^   ^   ^     ^
--  |   |   |   |   |   |     |
--  |   |   |   |   |   |     +----- custom data, optional
--  |   |   |   |   |   +----------- day of week (0 - 6) (Sunday=0)
--  |   |   |   |   +--------------- month (1 - 12)
--  |   |   |   +------------------- day of month (1 - 31)
--  |   |   +----------------------- hour (0 - 23)
--  |   +--------------------------- min (0 - 59)
--  +------------------------------- sec (0 - 59)
--
-- Cron table is a bit complex thing, but we support only few things
-- (see http://en.wikipedia.org/wiki/CRON_expression for full description)
--
-- +-----------------------------------------------------+
-- |    FIELD     |     VALUES      | SPECIAL CHARACTERS |
-- +--------------+-----------------+--------------------+
-- | Seconds      | 0-59            |       , - *        |
-- | Minutes      | 0-59            |       , - *        |
-- | Hours        | 0-23            |       , - *        |
-- | Day of month | 1-31            |       , - *        |
-- | Month        | 1-12 or JAN-DEC |       , - *        |
-- | Day of week  | 0-6 or SUN-SAT  |       , - *        |
-- +-----------------------------------------------------+
--
-- </pre>
--------------------------------------------------------------------------------

local unpack = unpack or table.unpack -- for Lua 5.1 / 5.4 compatibility
require 'lua-nucleo'

--------------------------------------------------------------------------------

local arguments,
      method_arguments,
      optional_arguments
      = import 'lua-nucleo/args.lua'
      {
        'arguments',
        'method_arguments',
        'optional_arguments'
      }

local is_number,
      is_table
      = import 'lua-nucleo/type.lua'
      {
        'is_number',
        'is_table'
      }

local tcount_elements,
      tijoin_many
      = import 'lua-nucleo/table-utils.lua'
      {
        'tcount_elements',
        'tijoin_many'
      }

local make_time_table,
      get_days_in_month,
      get_day_of_week,
      day_of_week_name_to_number,
      month_name_to_number
      = import 'lua-nucleo/datetime-utils.lua'
      {
        'make_time_table',
        'get_days_in_month',
        'get_day_of_week',
        'day_of_week_name_to_number',
        'month_name_to_number'
      }

local MAX_TIMESTAMP,
      unpack_timestamp
      = import 'lua-nucleo/timestamp.lua'
      {
        'MAX_TIMESTAMP',
        'unpack_timestamp'
      }

local make_enumerator_from_set,
      make_enumerator_from_interval
      = import 'lua-nucleo/enumerator.lua'
      {
        'make_enumerator_from_set',
        'make_enumerator_from_interval'
      }

--------------------------------------------------------------------------------

local make_next_occurrence_getter
do
  local make_enumerator_array
  do
    local get_first_till = function(self, max_enumerator)
      method_arguments(
          self
        )
      optional_arguments(
          "table", max_enumerator
        )
      local values = {}
      for i = 1, #self.enumerators_ do
        local current = self.enumerators_[i]
        values[#values + 1] = current:get_first()
        if current == max_enumerator then
          break
        end
      end
      return unpack(values)
    end

    make_enumerator_array = function(...)
      return
      {
        get_first_till = get_first_till;
        --
        enumerators_ = {...};
      }
    end
  end

  local MAX_ITERATIONS = MAX_TIMESTAMP

  --- Returns a timestamp of the next occurrence based on the cron instance cron
  -- properties and the 'base_time' timestamp as starting point
  -- @function cron:get_next_occurrence
  -- @tparam unix-timestamp base_time start point from which the
  -- occurrence is calculated
  -- @treturn unix-timestamp timestamp of the found occurrence or nil if not
  -- found
  local get_next_occurrence = function(self, base_time)
    method_arguments(
        self,
        "number", base_time
      )
    return self:get_next_occurrence_till(base_time, MAX_TIMESTAMP)
  end

  --- Returns a timestamp of the next occurrence based on the cron instance cron
  -- properties, 'base_timestamp' and 'end_timestamp'
  -- @function cron:get_next_occurrence_till
  -- @tparam unix-timestamp base_timestamp start point from which the
  -- occurrence is calculated
  -- @tparam unix-timestamp end_timestamp end point till which the
  -- occurrence is calculated. After that time point the occurrences will
  -- be nil.
  -- @treturn unix-timestamp timestamp of the found occurrence or nil if not
  -- found
  local get_next_occurrence_till = function(self, base_timestamp, end_timestamp)
    method_arguments(
        self,
        "number", base_timestamp,
        "number", end_timestamp
      )

    local SECONDS = self.seconds_
    local MINUTES = self.minutes_
    local HOURS = self.hours_
    local DAYS = self.days_
    local MONTHS = self.months_
    local DAYS_OF_WEEK = self.days_of_week_

    local enumerator_array =
      make_enumerator_array(SECONDS, MINUTES, HOURS, DAYS, MONTHS)

    local baseYear,
          baseMonth,
          baseDay,
          baseHour,
          baseMinute,
          baseSecond = unpack_timestamp(base_timestamp)

    local endYear, endMonth, endDay = unpack_timestamp(end_timestamp)

    local year = baseYear
    local month = baseMonth
    local day = baseDay
    local hour = baseHour
    local minute = baseMinute
    local second = baseSecond + 1

    -- Second
    second = SECONDS:get_next(second)
    if not second then
      second = enumerator_array:get_first_till(SECONDS)
      minute = minute + 1
    end

    -- Minute
    minute = MINUTES:get_next(minute)
    if not minute then
      second, minute = enumerator_array:get_first_till(MINUTES)
      hour = hour + 1
    elseif minute > baseMinute then
      second = enumerator_array:get_first_till(SECONDS)
    end

    -- Hour
    hour = HOURS:get_next(hour)
    if not hour then
      second, minute, hour = enumerator_array:get_first_till(HOURS)
      day = day + 1
    elseif hour > baseHour then
      second, minute = enumerator_array:get_first_till(MINUTES)
    end

    -- Day
    day = DAYS:get_next(day)

    local iterations = 0
    while true and iterations < MAX_ITERATIONS do
      iterations = iterations + 1
      if not day then
        second, minute, hour, day = enumerator_array:get_first_till(DAYS)
        month = month + 1
      elseif day > baseDay then
        second, minute, hour = enumerator_array:get_first_till(HOURS)
      end

      -- Month
      month = MONTHS:get_next(month)
      if not month then
        second, minute, hour, day, month =
          enumerator_array:get_first_till(MONTHS)
        year = year + 1
      elseif month > baseMonth then
        second, minute, hour, day = enumerator_array:get_first_till(DAYS)
      end

      --
      -- The day field in a cron expression spans the entire range of days
      -- in a month, which is from 1 to 31. However, the number of days in
      -- a month tend to be variable depending on the month (and the year
      -- in case of February). So a check is needed here to see if the
      -- date is a border case. If the day happens to be beyond 28
      -- (meaning that we're dealing with the suspicious range of 29-31)
      -- and the date part has changed then we need to determine whether
      -- the day still makes sense for the given year and month. If the
      -- day is beyond the last possible value, then the day/month part
      -- for the schedule is re-evaluated. So an expression like "0 0
      -- 15,31 * *" will yield the following sequence starting on midnight
      -- of Jan 1, 2000:
      --
      --  Jan 15, Jan 31, Feb 15, Mar 15, Apr 15, Apr 31, ...
      --

      local dateChanged =
        day ~= baseDay or month ~= baseMonth or year ~= baseYear

      if day > 28 and dateChanged and day > get_days_in_month(year, month) then
        if year >= endYear and month >= endMonth and day >= endDay then
          return false
        end
        day = nil
      else
        break;
      end
    end

    if iterations >= MAX_ITERATIONS then
      return nil, "endless loop detected"
    end

    local next_timestamp =
      os.time(make_time_table(day, month, year, hour, minute, second))

    if next_timestamp > end_timestamp then
      return nil, "next occurrence is after end date"
    end

    -- Day of week
    if DAYS_OF_WEEK:contains(get_day_of_week(next_timestamp)) then
      return next_timestamp
    end

    local new_base_timestamp =
      os.time(make_time_table(day, month, year, 23, 59, 59))

    return self:get_next_occurrence(new_base_timestamp, end_timestamp)
  end


  local load_cron_property = function(value, minv, maxv)
    if is_number(value) then
      return make_enumerator_from_interval(value, value)
    elseif is_table(value) then
      return make_enumerator_from_set(value)
    end
    return make_enumerator_from_interval(minv, maxv)
  end

  --- Makes the cron instance from cron properties
  -- @function make_next_occurrence_getter
  -- @tparam table cron_properties cron properties table
  -- @treturn table cron instance, see cron.* functions
  -- @see cron_properties_struct
  make_next_occurrence_getter = function(cron_properties)
    arguments(
        "table", cron_properties
      )

    local seconds
      = load_cron_property(cron_properties.seconds,      0, 59)
    local minutes
      = load_cron_property(cron_properties.minutes,      0, 59)
    local hours
      = load_cron_property(cron_properties.hours,        0, 23)
    local days
      = load_cron_property(cron_properties.days,         1, 31)
    local months
      = load_cron_property(cron_properties.months,       1, 12)
    local days_of_week
      = load_cron_property(cron_properties.days_of_week, 0,  6)

    local cron =
    {
      get_next_occurrence = get_next_occurrence;
      get_next_occurrence_till = get_next_occurrence_till;

      seconds_      = seconds;
      minutes_      = minutes;
      hours_        = hours;
      days_         = days;
      months_       = months;
      days_of_week_ = days_of_week;
    }

    --- cron custom data from cron properties
    cron.data = cron_properties.data;

    return cron
  end
end

--------------------------------------------------------------------------------

local make_cron_properties
do
  local load_date_field
  do
    local load_interval = function(data, value_extractor)
      arguments(
          "string", data,
          "function", value_extractor
        )

      local start_s, end_s = data:match("(%w+)%-(%w+)")
      if not start_s or not end_s then
        error("load_interval: can't parse cron property: `" .. data .."'")
      end

      local start_v, end_v = value_extractor(start_s), value_extractor(end_s)
      if not start_v then
        error("load_interval: can't extract value: `" .. start_s .."'")
      elseif not end_v then
        error("load_interval: can't extract value: `" .. end_s .."'")
      end

      if start_v > end_v then
        error(
            "load_interval: invalid interval: " .. start_v, " > ", end_v
          )
      end

      local values = {}
      for i = start_v, end_v do
        values[#values + 1] = i
      end
      return values
    end

    local load_single_value = function(data, value_extractor)
      arguments(
          "string", data,
          "function", value_extractor
        )

      if data:find("-") then
        return load_interval(data, value_extractor)
      end

      local value = value_extractor(data)
      if not value then
        error(
            "load_single_value: can't parse cron property: `" .. data .."'"
          )
      end

      return value
    end

    local load_array = function(data, value_extractor)
      arguments(
          "string", data,
          "function", value_extractor
        )
      local values = {}

      for v in data:gmatch("(.[^,]*),*") do
        local value = load_single_value(v, value_extractor)

        if is_number(value) then
          values[#values + 1] = value
        elseif is_table(value) then
          tijoin_many(values, value)
        else
          error("load_array: can't process value type: `" .. type(value) .."'")
        end
      end

      table.sort(values)
      return values
    end

    local load_repeated = function(data, value_extractor, minv, maxv)
      arguments(
          'string', data,
          'function', value_extractor
        )
      local values = { }

      for start, step in data:gmatch('(.[^/]*)/(.*)') do
        local start_value
        if start == '*' then
          start_value = minv
        else
          start_value = load_single_value(start, value_extractor)
        end

        if not is_number(start_value) and not is_table(start_value) then
          error(
            "load_repeated: can't process start value type: `"
              .. type(start) .."'"
          )
        end

        local step_value = tonumber(step)

        if not is_number(step_value) then
          error(
            "load_repeated: can't process step value type: `"
              .. type(step) .."'"
          )
        end
        if not (step_value > 0 and step_value <= maxv) then
          error(
            "load_repeated: can't process step value: `"
            .. tostring(step) .."'"
          )
        end

        if is_number(start_value) then
          local length = maxv - minv + 1
          if start_value > minv then
            local steps = math.floor((start_value - minv) / step_value)
            start_value = start_value - steps * step_value
          end
          for value = start_value, length - 1, step_value do
            values[#values + 1] = ((value - minv) % length) + minv
          end
        else
          for i = 1, #start_value, step_value do
            values[#values + 1] = start_value[i]
          end
        end

        if #values == 1 then
          values = values[1]
        end
      end

      return values
    end

    load_date_field = function(field_data, value_extractor, minv, maxv)
      arguments(
          "function", value_extractor
        )

      if field_data == nil or field_data == "*" then
        return nil
      elseif is_number(field_data) then
        return load_single_value(tostring(field_data), value_extractor)
      elseif field_data:find("/") then
        return load_repeated(field_data, value_extractor, minv, maxv)
      elseif field_data:find(",") then
        return load_array(field_data, value_extractor)
      end

      return load_single_value(field_data, value_extractor)
    end
  end

  local make_string_to_number_converter = function(minv, maxv)
    arguments(
        "number", minv,
        "number", maxv
      )
    assert(minv <= maxv)
    return function(v)
      arguments(
          "string", v
        )
      local n = tonumber(v)
      if not n then error('not a number: ' .. v) end
      if n < minv then error('too small value: ' .. n) end
      if n > maxv then error('too big value: ' .. n) end
      return n
    end
  end

  -- TODO: Check validity (including extra fields as minor)
  local make_cron_properties_from_hash = function(data)
    arguments(
        "table", data
      )
    local cron_properties_struct
    do
      --- Cron properties
      -- @tfield table/number/nil seconds possible second values
      -- @tfield table/number/nil minutes possible minute values
      -- @tfield table/number/nil hours possible hour values
      -- @tfield table/number/nil days possible day values
      -- @tfield table/number/nil months possible month values
      -- @tfield table/number/nil days_of_week possible day_of_week values
      -- @tfield[opt] any data custom data
      cron_properties_struct =
      {
        seconds = load_date_field(
            data.s, make_string_to_number_converter(0,59), 0, 59
          );
        minutes = load_date_field(
            data.m, make_string_to_number_converter(0,59), 0, 59
          );
        hours = load_date_field(
            data.h, make_string_to_number_converter(0,23), 0, 23
          );
        days = load_date_field(
            data.dom, make_string_to_number_converter(1,31), 1, 31
          );
        months = load_date_field(
            data.mon, month_name_to_number, 1, 12
          );
        days_of_week = load_date_field(
            data.dow, day_of_week_name_to_number, 0, 6
          );

        data = data.data;
      }
    end

    return cron_properties_struct
  end

  local make_cron_properties_from_array = function(data)
    arguments(
        "table", data
      )
    return make_cron_properties_from_hash(
        {
          s    = data[ 1];
          m    = data[ 2];
          h    = data[ 3];
          dom  = data[ 4];
          mon  = data[ 5];
          dow  = data[ 6];
          data = data[ 7];
        }
      )
  end

  --- Prepares cron properties from raw cron data
  -- @function make_cron_properties
  -- @tparam table raw_cron_data raw cron data table
  -- @treturn table cron properties
  -- @see raw_cron_data_struct_linear
  -- @see raw_cron_data_struct_hash
  make_cron_properties = function(raw_cron_data)
    arguments(
        "table", raw_cron_data
      )

    if tcount_elements(raw_cron_data) == #raw_cron_data then
      return make_cron_properties_from_array(raw_cron_data)
    end

    return make_cron_properties_from_hash(raw_cron_data)
  end
end

--------------------------------------------------------------------------------

--- Parses the 'cron_rule_string' string argument and returns raw cron data
-- table
-- @function make_raw_cron_data_from_string
-- @tparam string cron_rule_string (required)
-- @tparam[opt] table data Custom data associated with the rule,
-- default=nil
-- @tparam[optchain] boolean as_hash return table as hash table
-- instead of linear array, default=false
-- @treturn table raw cron data table
-- @see raw_cron_data_struct_linear
-- @see raw_cron_data_struct_hash
local make_raw_cron_data_from_string = function(cron_rule_string, data, as_hash)
  arguments(
      "string", cron_rule_string
    )
  optional_arguments(
      "boolean", as_hash
    )
  if as_hash == nil then as_hash = false end

  local seconds, minutes, hours, days, months, days_of_week =
    cron_rule_string:match(
        "%s*"
        .. "(.[^%s]*)" .. "%s*"
        .. "(.[^%s]*)" .. "%s*"
        .. "(.[^%s]*)" .. "%s*"
        .. "(.[^%s]*)" .. "%s*"
        .. "(.[^%s]*)" .. "%s*"
        .. "(.[^%s]*)" .. "%s*"
      )

  if as_hash then
    local raw_cron_data_struct_hash
    do
      --- Raw cron data as hash array
      -- @tfield string s seconds rule
      -- @tfield string m minutes rule
      -- @tfield string h hours rule
      -- @tfield string dom days rule
      -- @tfield string mon months rule
      -- @tfield string dow days_of_week rule
      -- @tfield[opt] any data custom data
      raw_cron_data_struct_hash =
      {
        s   = seconds;
        m   = minutes;
        h   = hours;
        dom = days;
        mon = months;
        dow = days_of_week;

        data = data;
      }
    end

    return raw_cron_data_struct_hash
  end

  local raw_cron_data_struct_linear
  do
    --- Raw cron data as linear array
    -- @tfield string 1 seconds rule
    -- @tfield string 2 minutes rule
    -- @tfield string 3 hours rule
    -- @tfield string 4 days rule
    -- @tfield string 5 months rule
    -- @tfield string 6 days_of_week rule
    -- @tfield[opt] any 7 custom data
    raw_cron_data_struct_linear =
      { seconds, minutes, hours, days, months, days_of_week, data }
  end

  return raw_cron_data_struct_linear
end

--------------------------------------------------------------------------------

--- Makes a crontab from raw crontab data
-- @function make_crontab
-- @tparam table raw_crontab_data raw crontab data table
-- @treturn table array of cron properties
-- @see raw_cron_data_struct_linear
-- @see raw_cron_data_struct_hash
-- @see cron_properties_struct
local make_crontab = function(raw_crontab_data)
  arguments(
      "table", raw_crontab_data
    )
  local crons = {}
  for i = 1, #raw_crontab_data do
    crons[#crons + 1] = make_cron_properties(raw_crontab_data[i])
  end
  return crons
end

--------------------------------------------------------------------------------

return
{
  _VERSION = '1.0.0';
  _URL = 'https://github.com/logiceditor-com/lua-crontab';
  _COPYRIGHT = 'Copyright (c) 2010-2021 lua-crontab authors';
  _LICENSE = 'MIT (http://raw.githubusercontent.com/'
    .. 'logiceditor-com/lua-crontab/master/COPYRIGHT)';
  _DESCRIPTION = 'stores crons, determines next occurrence of cron';

  --

  make_crontab = make_crontab; -- crontab contains cron_properties
  make_cron_properties = make_cron_properties;
  make_raw_cron_data_from_string = make_raw_cron_data_from_string;
  make_next_occurrence_getter = make_next_occurrence_getter;
}
