--------------------------------------------------------------------------------
-- test.lua: tests for all modules of the library
-- This file is a part of lua-crontab library
-- Copyright (c) 2010-2021 lua-crontab authors
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

require 'lua-nucleo'

--------------------------------------------------------------------------------

local run_test
      = import 'lua-nucleo/suite.lua'
      {
        'run_test'
      }

run_test(
    'test/crontab-tests.lua',
    { seed_value = 12345, strict_mode = false }
  )
