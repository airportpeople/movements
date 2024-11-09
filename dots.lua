-- dots
--
-- See docs.

-- norns `require` statements
-- x = require('module')

engine.name = "d_Timber"

-- script components
d_timber = include 'lib/d_timber'
d_ui = include 'lib/d_ui'
d_dots = include 'lib/d_dots'
d_grid = include 'lib/d_grid'
d_sample = include 'lib/d_sample'

HOLD_K1 = false
REDRAW_FRAMERATE = 30  -- same for grid and screen
DISPLAY_ID = 1
PAGE_ID = 1



-----------------------------------------------------------------
-- TIMBER
-----------------------------------------------------------------


-----------------------------------------------------------------
-- INIT
-----------------------------------------------------------------

function init()
  -- parameters
  d_sample.build_params()
  d_dots.build_params()

  -- inits
  d_dots.init()
  d_ui.init()
  
  -- redraw clock
  screen_dirty = true
  grid_dirty = true
  clock.run(redraw_clock)
end

-----------------------------------------------------------------
-- UI
-----------------------------------------------------------------

function redraw()
  screen.clear()

  d_ui.draw_nav()

  display[DISPLAY_ID]:redraw()
  d_ui[display_names[DISPLAY_ID] .. "_" .. PAGE_ID .."_redraw"]()

  screen.update()
end

function key(n, z)
  if n == 1 then
    if z == 1 then
      HOLD_K1 = true
    else
      HOLD_K1 = false
    end
  end

  d_ui[display_names[DISPLAY_ID] .. "_" .. PAGE_ID .."_key"](n,z)
  
end

function enc(n, d)
  if n == 1 then
    if HOLD_K1 then
      DISPLAY_ID = util.clamp(DISPLAY_ID + d, 1, #display_names)
      PAGE_ID = 1
    else
      display[DISPLAY_ID]:set_index_delta(d, false)
      PAGE_ID = display[DISPLAY_ID].index
    end
  end
  screen_dirty = true
end

function redraw_clock()
  while true do
    clock.sleep(1/REDRAW_FRAMERATE)
    
    if screen_dirty then
      redraw()
      screen_dirty = false
    end

    if grid_dirty then
      d_grid:grid_redraw()
      grid_dirty = false
    end

  end
end
