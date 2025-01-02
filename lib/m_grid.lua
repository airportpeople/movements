-- all the basic grid operations (?)
-- redraw thing?

-- navigate on grid --> navigate on norns
-- navigate on norns --> grid remains static
-- all screen pages (except dots) correspond to grid pages
-- add dots to the end, maybe with a | separator from the rest

local m_grid = {}

g = grid.connect()  -- requires 8x16 grid

g_brightness = {
  bank_sample_empty = 0,
  bank_sample_loaded = 2,
  bank_sample_selected = 15,
  bank_sample_playing = 12,
  bank_sample_tracked = 4,
  bank_sample_current_track = 6,
  bank_sample_cued = 9,
  bank_empty = 2,
  bank_loaded = 4,
  bank_selected = 8,
  nav_page_inactive = 2,
  nav_page_active = 5,
  mode_focus = 0,
  mode_play = 10,
  alt_off = 0,
  alt_on = 15,
  step_active = 14,
  step_inactive = 8,
  step_empty = 0,
  seq_track_selected = 2,
  seq_step_range = 4,
  level_met = 5,
  bar_active = 12,
  bar_empty = 0,
  bar_populated = 3,
  bar_moving = 6,
  track_selected = 8,
  track_playing = 10,
  track_stopped = 0,
  time_beats = 10,
  time_seconds = 2,
  clock_frac_selected = 7,
  clock_frac_deselected = 0,
  clock_frac_highlighted = 3,
  param_selected = 5,
  param_deselected = 1,
  play_mode_selected = 10,
  play_mode_deselected = 0,
  sample_range_in = 5,
  sample_range_out = 1
}

-- tables with 1 or 2 page options for each nav key
g_pages = {
  {'sample_seq', 'sample_levels'}, {'sample_time'}, {'sample_config'},
  {'tape_seq', 'tape_levels'}, {'tape_time'}, {'tape_config'},
}

-- order of play modes on grid
g_play_modes_all = {
  buffer = {"Loop", "Inf. Loop", "1-Shot", "Gated"},
  streaming = {"Loop", "Loop", "1-Shot", "Gated"},
  tape_slice = {"Loop", "Loop", "1-Shot", "Gated"}
}

G_PAGE = 'sample_config'
PLAY_MODE = false
ALT = false

-- keys held [y][x] or [row][col]
-- 1 == held and 0 == not held
KEY_HOLD = {}

SEQ_BAR = 1  -- current sequence bar
TRACK = 1    -- selected (sample) track
BUFFER = 1   -- recording buffer selected (1 -> L, 2 -> R)
PARAM = 'amp'

-----------------------------------------------------------------
-- INIT
-----------------------------------------------------------------

function m_grid.init()
  -- param options at the bottom of config page.
  -- the last one is only assumed if all are deselected
  p_options.PARAMS = {
    'pan', 'filter', 'delay', 'scale', 'rate', 'prob', 'amp'
  }

  m_grid.build_param_levels()

  -- key_hold map
  for r = 1,8 do
    KEY_HOLD[r] = {}
    for c = 1,16 do
      KEY_HOLD[r][c] = 0
    end
  end
end

function m_grid.build_param_levels()
  -- parameter level values on the grid (see p_options.PARAMS).
  -- *the "zero" value is the 7th item in the list!*
  param_levels = {}

  -- For amp, ignore peek ... #s are converted to [0, 1].
  -- *Timber Engine needs these converted to db*
  param_levels.amp = {-24, -18, -12, -6, -3, 0}
  for i=1,6 do param_levels.amp[i] = util.dbamp(param_levels.amp[i]) end
  table.insert(param_levels.amp, 0)

  param_levels.length = {1/6, 2/6, 3/6, 4/6, 5/6, 1, 0}
  param_levels.prob = {1/6, 2/6, 3/6, 4/6, 5/6, 1, 0}
  param_levels.pan = {-1, -2/3, -1/3, 1/3, 2/3, 1, 0}

  -- for filter, the "zero" value translates to swapping from HP <--> LP
  -- for LP, highlight up to the value, for HP, highlight above the value
  -- final value: filter > 0 = LP freq and filter < 0 = HP freq
  param_levels.filter = {100, 500, 1000, 5000, 10000, 20000, -1}

  param_levels.scale = {-3, -2, -1, 1, 2, 3, 0}

  -- TODO: for buffer samples, rate < 0 translates to start/end frame reversal
  param_levels.rate = {-2, -1, -1/2, 1/2, 1, 2, 0}

end


-----------------------------------------------------------------
-- NAVIGATION
-----------------------------------------------------------------

function m_grid.draw_nav()
  local origin = {9, 8}
  
  -- pages
  for i = 1, #g_pages do
    x, y = global_xy(origin, i, 1)

    if tab.contains(g_pages[i], G_PAGE) then
      g:led(x, y, g_brightness.nav_page_active)
    else
      g:led(x, y, g_brightness.nav_page_inactive)
    end
  end

  -- mode
  if PLAY_MODE then
    g:led(15, 8, g_brightness.mode_play)
  else
    g:led(15, 8, g_brightness.mode_focus)
  end

  -- alt
  if ALT then
    g:led(16, 8, g_brightness.alt_on)
  else
    g:led(16, 8, g_brightness.alt_off)
  end

end

function m_grid.nav_key(x, y, z)

  -- page selection
  if 9 <= x and x < 15 and y == 8 then
    if z == 1 then
      if #g_pages[x - 8] > 1 and tab.contains(g_pages[x - 8], G_PAGE) then
        i = index_of(g_pages[x - 8], G_PAGE)
        i = util.wrap(i + 1, 1, #g_pages[x - 8])
      else
        i = 1
      end
      G_PAGE = g_pages[x - 8][i]
      
      -- if needed, set TRACK to "first" within a functionality
      if string.match(G_PAGE, '^sample') and TRACK > 7 then 
        TRACK = 1
      elseif string.match(G_PAGE, '^tape') and TRACK < 8 then
        TRACK = 8
      end

    end
  
  -- mode
  elseif x == 15 and y == 8 then
    if z == 1 then
      PLAY_MODE = not PLAY_MODE
    end
  
  -- alt
  elseif x == 16 and y == 8 then
    if z == 1 then
      ALT = true
    else
      ALT = false
    end
  end

  grid_dirty = true
end

-----------------------------------------------------------------
-- SEQUENCE
-----------------------------------------------------------------

function m_grid.seq_redraw(track_range)

  -- draw steps and selected track
  for track = track_range[1], track_range[2] do
    local y = track - track_range[1] + 1
    
    for s = 1,16 do
      step_ = (SEQ_BAR - 1) * 16 + s
      
      if step_ == step[track] then
        g:led(s, y, g_brightness.step_active)
      elseif pattern[track][bank[track]][step_] > 0 then
        g:led(s, y, g_brightness.step_inactive)
      elseif step_range[track][1] <= step_ 
              and step_ <= step_range[track][2] then
        g:led(s, y, g_brightness.seq_step_range)
      elseif track ~= TRACK then
        g:led(s, y, g_brightness.step_empty)
      else
        g:led(s, y, g_brightness.seq_track_selected)
      end
    end
  end

  -- draw sequence bars
  draw_sequence_bars(1, 8, track_range)

end

function m_grid.seq_key(x, y, z, track_range)
  local n_tracks = track_range[2] - track_range[1] + 1
  local track = track_range[1] - 1 + y

  if y <= n_tracks and z == 1 then
    step_ = (SEQ_BAR - 1) * 16 + x

    if not PLAY_MODE then
      -- select track
      if ALT then
        TRACK = track
      -- activate step
      else
        m_seq.toggle_pattern_step(track, step_)
      end
    else
      -- move all tracks to that step
      if ALT then
        for track_ = track_range[1], track_range[2] do
          step[track_] = step_
        end
      -- move just the associated track to that step
      else
        step[track] = step_
      end
    end
  end

  -- step range (only in focus mode)
  if y <= n_tracks and not PLAY_MODE then
    m_grid.set_step_range(x, y, z, track)
  end
  
  if y == 8 and x < 9 then
    if z == 1 then
      
      -- copy bar for selected track
      if ALT and KEY_HOLD[8][SEQ_BAR] > 0 and x ~= SEQ_BAR then
        m_grid.copy_track_pattern(SEQ_BAR, x)
      end

      SEQ_BAR = x
    end
  end
  
  screen_dirty = true
  grid_dirty = true
end

-- **KEY FUNCTION**
-- given current x, y, z of key press, determine whether to set 
-- a step range for track `track`. *allow for z == 0 and z == 1.*
function m_grid.set_step_range(x, y, z, track)
  local bar_0 = (SEQ_BAR - 1) * 16

  if z == 1 then
    KEY_HOLD[y][x] = 1
    hold_span = span(KEY_HOLD[y])
    -- selecting whole range removes "mini range"
    if hold_span[2] - hold_span[1] == 15 then
      step_range[track] = {0, 0}
      step_range_updated = {bar_0 + 1, bar_0 + 16}
    elseif hold_span[2] > hold_span[1] then
      step_range[track][1] = bar_0 + hold_span[1]
      step_range[track][2] = bar_0 + hold_span[2]
      step_range_updated = step_range[track]
    end
  else
    KEY_HOLD[y][x] = 0
    if step_range_updated then
      -- undo the de/selection that came from setting the range
      m_seq.toggle_pattern_step(track, step_range_updated[1])
      m_seq.toggle_pattern_step(track, step_range_updated[2])
      step_range_updated = nil
    end
  end
end


-----------------------------------------------------------------
-- LEVELS
-----------------------------------------------------------------

function m_grid.levels_redraw()

  for s = 1,16 do
    step_ = (SEQ_BAR - 1) * 16 + s
    
    -- draw steps for selected track
    if step_ == step[TRACK] then
      g:led(s, 1, g_brightness.step_active)
    elseif pattern[TRACK][bank[TRACK]][step_] > 0 then
      g:led(s, 1, g_brightness.step_inactive)
    elseif step_range[TRACK][1] <= step_ 
          and step_ <= step_range[TRACK][2] then
      g:led(s, 1, g_brightness.seq_step_range)
    else
      g:led(s, 1, g_brightness.seq_track_selected)
    end

    -- draw levels for selected parameter
    -- TAG: param 3
    if pattern[TRACK][bank[TRACK]][step_] > 0 then
      value_ = param_pattern[PARAM][TRACK][bank[TRACK]][step_]

      -- fill
      if tab.contains({'amp'}, PARAM) then

        for i=1,6 do
          if value_ >= param_levels[PARAM][i] then
            g:led(s, 8 - i, g_brightness.level_met)
          end
        end

      end

      -- centered value (handle fraction rounding)
      if tab.contains({'pan'}, PARAM) then
        for i = 1,6 do
          if value_ > 0 and i >= 4 then
            if value_ >= param_levels[PARAM][i] - 0.001 then
              g:led(s, 8 - i, g_brightness.level_met)
            end
          elseif value_ < 0 and i <= 3 then
            if value_ <= param_levels[PARAM][i] + 0.001 then
              g:led(s, 8 - i, g_brightness.level_met)
            end
          end
        end
      end

      -- swapping filter
      if PARAM == 'filter' and value_ then
        
        for i = 1,6 do
          if params:get('track_' .. TRACK .. '_filter_type') == 1 then
            if value_ >= param_levels[PARAM][i] - 0.001 then
              g:led(s, 8 - i, g_brightness.level_met)
            end
          else
            if value_ <= param_levels[PARAM][i] + 0.001 then
              g:led(s, 8 - i, g_brightness.level_met)
            end
          end
        end

      end

    end

  end

  if PLAY_MODE then
    -- draw param selection
    for p = 1,6 do
      if PARAM == p_options.PARAMS[p] then
        g:led(p, 8, g_brightness.param_selected)
      else
        g:led(p, 8, g_brightness.param_deselected)
      end
    end
  else
    -- draw sequence bars
    draw_sequence_bars(1, 8, {TRACK, TRACK})
  end

end

function m_grid.levels_key(x, y, z)
  if y < 8 then
    step_ = (SEQ_BAR - 1) * 16 + x
  end

  if y == 1 and not PLAY_MODE then
    m_grid.set_step_range(x, y, z, TRACK)
  end

  if y == 1 and z == 1 then
    if not PLAY_MODE then
      empty_step_ = pattern[TRACK][bank[TRACK]][step_] == 0
      pattern[TRACK][bank[TRACK]][step_] = empty_step_ and 1 or 0

      -- reset "new" step parameters to track value
      if empty_step_ then
        if PARAM == 'filter' then
          default = params:get('track_' .. TRACK .. '_filter_freq')
        else
          default = params:get('track_' .. TRACK .. '_' .. PARAM)
        end
        
        param_pattern[PARAM][TRACK][bank[TRACK]][step_] = default
      end
    else
      -- move track to that step
      step[TRACK] = step_
    end
  end
  
  if PLAY_MODE then
    -- param selection
    if x < 7 and y == 8 and z == 1 then
      if p_options.PARAMS[x] == PARAM then
        PARAM = 'amp'
      else
        PARAM = p_options.PARAMS[x]
      end
    end
  else
    if y == 8 and x < 9 then
      if z == 1 then
        -- copy bar for selected track
        if ALT and KEY_HOLD[8][SEQ_BAR] > 0 and x ~= SEQ_BAR then
          m_grid.copy_track_pattern(SEQ_BAR, x)
        end
  
        SEQ_BAR = x
      end
    end
  end

  if 1 < y and y < 8 and z == 1 and pattern[TRACK][bank[TRACK]][step_] > 0 then

    if PARAM == 'filter' then
      -- current parameter value at that step
      param_value = param_pattern[PARAM][TRACK][bank[TRACK]][step_]
      value = m_grid.select_param_value(PARAM, 8 - y, param_value)

      -- not selecting the same key
      if value > 0 then
        param_pattern[PARAM][TRACK][bank[TRACK]][step_] = value
      end
      
    else
      -- current parameter value at that step
      param_value = param_pattern[PARAM][TRACK][bank[TRACK]][step_]
      value = m_grid.select_param_value(PARAM, 8 - y, param_value)
      param_pattern[PARAM][TRACK][bank[TRACK]][step_] = value
    end
    
  end

  grid_dirty = true
end

-----------------------------------------------------------------
-- TIME
-----------------------------------------------------------------
function m_grid.time_redraw(track_range)

  for t = track_range[1], track_range[2] do
    local y = t - track_range[1] + 1

    -- play/stop column
    if transport[t] then
      g:led(1, y, g_brightness.track_playing)
    else
      g:led(1, y, g_brightness.track_stopped)
    end

    -- beat/sec column
    if time_type[t] == 'beats' then
      g:led(2, y, g_brightness.time_beats)
    else
      g:led(2, y, g_brightness.time_seconds)
    end

    -- time rows
    local frac = 1
    for c = 4,16 do
      frac = c - 3
      -- in selected range
      if clock_range[t][1] <= frac and frac <= clock_range[t][2] then
        g:led(c, y, g_brightness.clock_frac_selected)
      -- indicate 1/8, 1/4, 1, and 4 
      elseif not ALT and tab.contains({1, 5, 8, 11}, frac) then
        g:led(c, y, g_brightness.clock_frac_highlighted)
      -- indicate 1/6, 1/3, 1, 3, and 6
      elseif ALT and tab.contains({3, 6, 8, 10, 13}, frac) then
        g:led(c, y, g_brightness.clock_frac_highlighted)
      else
        g:led(c, y, g_brightness.clock_frac_deselected)
      end
    end
  end

end

function m_grid.time_key(x, y, z, track_range)
  
  local n_tracks = track_range[2] - track_range[1] + 1
  local track = track_range[1] - 1 + y
  
  if y <= n_tracks then
    -- play/stop
    if x == 1 and z == 1 then
      if transport[track] then
        m_seq.stop_transport(track)
      else
        m_seq.start_transport(track)
      end
    end

    -- beats or seconds
    if x == 2 and z == 1 then
      if time_type[track] == 'beats' then
        time_type[track] = 'seconds'
      else
        time_type[track] = 'beats'
      end
    end

    -- clock fraction range
    if x > 3 then
      if z == 1 then
        KEY_HOLD[y][x] = 1
        hold_span = span(KEY_HOLD[y])
        clock_range[track][1] = hold_span[1] - 3
        clock_range[track][2] = hold_span[2] - 3
      else
        KEY_HOLD[y][x] = 0
      end
    end
  end

  grid_dirty = true
end

-----------------------------------------------------------------
-- SAMPLE SEQ 
-----------------------------------------------------------------

function m_grid.sample_seq_redraw()
  m_grid.seq_redraw({1, 7})
end

function m_grid.sample_seq_key(x, y, z)
  m_grid.seq_key(x, y, z, {1, 7})
end

-----------------------------------------------------------------
-- SAMPLE LEVELS 
-----------------------------------------------------------------

function m_grid.sample_levels_redraw()
  m_grid.levels_redraw()
end

function m_grid.sample_levels_key(x, y, z)
  m_grid.levels_key(x, y, z)
end

-----------------------------------------------------------------
-- SAMPLE TIME 
-----------------------------------------------------------------

function m_grid.sample_time_redraw()
  m_grid.time_redraw({1, 7})
end

function m_grid.sample_time_key(x, y, z)
  m_grid.time_key(x, y, z, {1, 7})
end

-----------------------------------------------------------------
-- SAMPLE CONFIG 
-----------------------------------------------------------------

function m_grid.draw_bank(bank)
  local origin = {9, 1}

  -- draw bank samples
  for row = 1,4 do
    for col = 1,8 do
      x, y = global_xy(origin, col, row)
      sample_id_ = banks[bank][row][col]
      if sample_id_ then
        -- sample is assigned to a track
        if tab.contains(flatten(track_pool), sample_id_) then
          if tab.contains(track_pool[TRACK], sample_id_) then
            g:led(x, y, g_brightness.bank_sample_current_track)
          else
            g:led(x, y, g_brightness.bank_sample_tracked)
          end

          -- show track that sample is loaded into
          if KEY_HOLD[y][x] == 1 then
            g:led(8, find(track_pool, sample_id_), 
                  g_brightness.bank_sample_tracked)
          end

        else
          g:led(x, y, g_brightness.bank_sample_loaded)
        end

        -- show cue if not already loaded into the selected track
        if tab.contains(track_pool_cue[TRACK][bank], sample_id_) and 
          not tab.contains(track_pool[TRACK], sample_id_) then
          g:led(x, y, g_brightness.bank_sample_cued)
        end
        
        if sample_status[sample_id_] == 1 and PLAY_MODE then
          g:led(x, y, g_brightness.bank_sample_playing)
        end

      else
        g:led(x, y, g_brightness.bank_sample_empty)
      end
    end
  end

  -- draw bank indicators
  origin = {13, 5}
  for bank_ = 1,4 do
    x, y = global_xy(origin, bank_, 1)

    if BANK == bank_ then
      g:led(x, y, g_brightness.bank_selected)
    elseif bank_folders[bank_] then
      g:led(x, y, g_brightness.bank_loaded)
    else
      g:led(x, y, g_brightness.bank_empty)
    end

  end

  -- draw playback modes
  for i = 1,4 do
    if m_sample.play_mode_option(SAMPLE) == g_play_modes[i] then
      g:led(8 + i, 5, g_brightness.play_mode_selected)
    else
      g:led(8 + i, 5, g_brightness.play_mode_deselected)
    end
  end

  -- draw sample range
  sample_range = sample_frame_grid(SAMPLE)
  for i = 1,16 do
    row_ = (i - 1) // 8 + 1
    col_ = i - (row_ - 1) * 8

    if sample_range[i] > 0 then
      g:led(8 + col_, 5 + row_, g_brightness.sample_range_in)
    else
      g:led(8 + col_, 5 + row_, g_brightness.sample_range_out)
    end
  end

  -- show selected sample (or bank it's in) if current bank is held
  for bank_ = 1,4 do
    x, y = global_xy(origin, bank_, 1)

    if KEY_HOLD[y][x] == 1 and SAMPLE and not PLAY_MODE then
      b_, r_, c_ = id_bankrowcol(SAMPLE)
      if b_ == BANK then
        -- highlight selected sample in bank
        g:led(c_ + 8, r_, g_brightness.bank_sample_selected)
      else
        -- highlight bank location
        g:led(b_ + 12, 5, g_brightness.bank_selected)
      end
    end
  end

  -- track selected for bank (overwrites the "find track")
  for y = 1,7 do
    if y == TRACK then
      g:led(8, y, g_brightness.track_selected)
    end
  end
  

end

function m_grid.draw_tracks()

  for y = 1,7 do
    for i=1,6 do

      -- TAG: param 4
      -- fill
      if tab.contains({'amp'}, PARAM) then
        p = 'track_' .. y .. '_' .. PARAM
        if params:get(p) >= param_levels[PARAM][i] then
          g:led(i, y, g_brightness.level_met)
        end
      end

      -- 0-centered value
      if tab.contains({'pan'}, PARAM) then
        p = 'track_' .. y .. '_' .. PARAM
        if params:get(p) > 0 and i >= 4 then
          if params:get(p) >= param_levels[PARAM][i] - 0.001 then
            g:led(i, y, g_brightness.level_met)
          end
        elseif params:get(p) < 0 and i <= 3 then
          if params:get(p) <= param_levels[PARAM][i] + 0.001 then
            g:led(i, y, g_brightness.level_met)
          end
        end
      end

      -- filter swapping
      if PARAM == 'filter' then
        p_freq = 'track_' .. y .. '_filter_freq'
        p_type = 'track_' .. y .. '_filter_type'

        if params:get(p_type) == 1 then
          if params:get(p_freq) >= param_levels[PARAM][i] - 0.001 then
            g:led(i, y, g_brightness.level_met)
          end
        else
          if params:get(p_freq) <= param_levels[PARAM][i] + 0.001 then
            g:led(i, y, g_brightness.level_met)
          end
        end
      end

    end
  end

end

function m_grid.sample_config_redraw()
  m_grid.draw_bank(BANK)
  m_grid.draw_tracks()

  -- draw param selection
  for p = 1,6 do
    if PARAM == p_options.PARAMS[p] then
      g:led(p, 8, g_brightness.param_selected)
    else
      g:led(p, 8, g_brightness.param_deselected)
    end
  end

end

function m_grid.sample_config_key(x, y, z)

  -- bank selection
  if 12 < x and y == 5 then
    if z == 1 then
      local b = x - 12

      -- copy bank patterns for selected track
      if ALT and KEY_HOLD[5][BANK + 12] > 0 and b ~= BANK then
        m_grid.copy_bank_pattern(BANK, b)
      end

      BANK = b
    end
  end

  -- play mode selection
  if 8 < x and x < 13 and y == 5 and z == 1 then
    i = m_sample.play_mode_i(SAMPLE, g_play_modes[x - 8])
    params:set('play_mode_' .. SAMPLE, i)
  end

  -- track selection
  if x == 8 and y < 8 then
    if z == 1 then
      -- load onto track (only if track already selected)
      if TRACK == y and ALT then
        m_seq.load_track_pool(TRACK)
      end
      TRACK = y

      -- show bank linked to track
      if #track_pool[TRACK] > 0 then
        BANK = bank[TRACK]
      end
    end
  end

  -- sample selection
  if 8 < x and y < 5 then
    row_ = y
    col_ = x - 8
    sample_id = rowcol_id(row_ .. col_, BANK)
    
    if z == 1 then
      m_sample.set_sample_id(sample_id)
      
      -- play sample
      if PLAY_MODE then
        if sample_status[sample_id] == 1 then
          m_sample.note_off(sample_id)
        else
          m_sample.note_on(sample_id, 1)
        end
      
      -- assign samples
      elseif ALT then

        -- check sample exists
        if banks[BANK][row_][col_] then

          -- if not already set in a track pool, then add to cue
          if not tab.contains(flatten(track_pool), sample_id) then

            for track = 1,7 do
              track_cue = track_pool_cue[track][BANK]
              -- if not in TRACK cue, then add it
              if track == TRACK and not tab.contains(track_cue, sample_id) then
                table.insert(track_cue, sample_id)
              -- otherwise, in any case, remove it from the cue
              elseif tab.contains(track_cue, sample_id) then
                table.remove(track_cue, index_of(track_cue, sample_id))
              end
            end
          
          -- otherwise, if sample in the current track pool, remove it
          elseif tab.contains(track_pool[TRACK], sample_id) then
            table.remove(track_pool[TRACK], 
            index_of(track_pool[TRACK], sample_id))

            -- set parameters back to default
            m_sample.sample_params_to_default({sample_id})
          end
        end
      end
    else
      
      if PLAY_MODE and sample_status[sample_id] > 0 and play_mode_is_hold(sample_id) then
        m_sample.note_off(sample_id)
      end

    end
  end

  -- track param levels
  if x < 7 and y < 8 and z == 1 then

    if PARAM == 'filter' then
      local f_type = params:get('track_' .. y .. '_filter_type')
      local f_freq = params:get('track_' .. y .. '_filter_freq')

      value = m_grid.select_param_value(PARAM, x, f_freq)

      if value == -1 then
        params:set('track_' .. y .. '_filter_type', f_type % 2 + 1)
      else
        params:set('track_' .. y .. '_filter_freq', value)
      end
      
    else
      param_value = params:get('track_' .. y .. '_' .. PARAM)
      value = m_grid.select_param_value(PARAM, x, param_value)
      params:set('track_' .. y .. '_' .. PARAM, value)
    end
    
  end

  -- param selection
  if x < 7 and y == 8 and z == 1 then
    if p_options.PARAMS[x] == PARAM then
      PARAM = 'amp'
    else
      PARAM = p_options.PARAMS[x]
    end
  end

  -- slice adjustment ...
  if 5 < y and y < 8 and 8 < x and z == 1 then
    i = 8 * (y - 6) + (x - 8)

    if ALT then
      grid_sample_end(SAMPLE, i)
    else
      grid_sample_start(SAMPLE, i)
    end

  end

  grid_dirty = true
  screen_dirty = true
end

-----------------------------------------------------------------
-- TAPE SEQ
-----------------------------------------------------------------

function m_grid.tape_seq_redraw()
  m_grid.seq_redraw({8, 11})
end

function m_grid.tape_seq_key(x, y, z)
  m_grid.seq_key(x, y, z, {8, 11})
end

-----------------------------------------------------------------
-- TAPE LEVELS
-----------------------------------------------------------------

function m_grid.tape_levels_redraw()
  m_grid.levels_redraw()
end

function m_grid.tape_levels_key(x, y, z)
  m_grid.levels_key(x, y, z)
end

-----------------------------------------------------------------
-- TAPE TIME
-----------------------------------------------------------------

function m_grid.tape_time_redraw()
  m_grid.time_redraw({8, 11})
end

function m_grid.tape_time_key(x, y, z)
  m_grid.time_key(x, y, z, {8, 11})
end

-----------------------------------------------------------------
-- TAPE CONFIG
-----------------------------------------------------------------
temp_on = {}

-- temporary redraw
function m_grid.tape_config_redraw()

  for i = 1,8 do
    g:led(i + 6, i, 3)
  end

  if temp_on[1] then
    g:led(temp_on[1], temp_on[2], 10)
  end

end

function m_grid.tape_config_key(x, y, z)
  if z == 1 then
    temp_on = {x, y}
  else
    temp_on = {}
  end
  grid_dirty = true
end

-----------------------------------------------------------------
-- REDRAW
-----------------------------------------------------------------

function m_grid:grid_redraw()
  g:all(0)
  m_grid[G_PAGE .. '_redraw']()
  m_grid.draw_nav()
  g:refresh()
end


function g.key(x, y, z)

  if z == 1 then
    KEY_HOLD[y][x] = 1
  else
    KEY_HOLD[y][x] = 0
  end

  if x > 8 and y == 8 then
    m_grid.nav_key(x, y, z)
  else
    m_grid[G_PAGE .. '_key'](x, y, z)
  end

end

-----------------------------------------------------------------
-- UTILITY
-----------------------------------------------------------------

-- return a 16-step array with 1s encompassing the sample start and
-- end, with 0s otherwise.
function sample_frame_grid(id)
  local start_frame = params:get('start_frame_' .. id)
  local end_frame = params:get('end_frame_' .. id)
  local num_frames = samples_meta[id]['num_frames']
  local grid_range = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}

  if num_frames == 0 then
    return grid_range
  end

  first_frame = math.min(start_frame, end_frame)
  last_frame = math.max(start_frame, end_frame)

  interval = num_frames / 16

  start_ = first_frame // interval + 1
  stop_ = last_frame // interval
  for i = start_, math.max(start_, stop_) do
    grid_range[i] = 1
  end

  return grid_range
end

function grid_sample_start(id, i_16)
  local num_frames = samples_meta[id]['num_frames']
  local interval = num_frames / 16

  if num_frames > 0 then
    -- frame associated with the start of the i_16th step of 16
    frame = math.ceil(interval * (i_16 - 1))
    params:set('start_frame_' .. id, frame)
  end
  
end

function grid_sample_end(id, i_16)
  local num_frames = samples_meta[id]['num_frames']
  local interval = num_frames / 16

  if num_frames > 0 then
    -- frame associated with the end of the i_16th step of 16
    frame = math.ceil(interval * i_16)
    params:set('end_frame_' .. id, frame)
  end
  
end

-- "global" grid x and y from *relative* x and y from origin. 
-- origin is {n_cols, n_rows} and this is *1-indexed*
function global_xy(origin, x_rel, y_rel)
  x = origin[1] - 1 + x_rel
  y = origin[2] - 1 + y_rel
  return x, y
end 

-- "relative" grid x and y from *global* x and y given origin. 
-- origin is {n_cols, n_rows} and this is *1-indexed*
function rel_xy(origin, x_global, y_global)
  x = x_global - origin[1] + 1
  y = y_global - origin[2] + 1
  return x, y
end

-- copy 16 pattern steps and parameter pattern values `from_bar` to 
-- `to_bar` (typically correspond to SEQ_BAR and another bar).
function m_grid.copy_track_pattern(from_bar, to_bar)

  for i = 1,16 do
    paste_step = pattern[TRACK][bank[TRACK]][(from_bar - 1) * 16 + i]
    pattern[TRACK][bank[TRACK]][(to_bar - 1) * 16 + i] = paste_step

    for p, pattern_ in pairs(param_pattern) do
      paste_param = pattern_[TRACK][bank[TRACK]][(from_bar - 1) * 16 + i]
      param_pattern[p][TRACK][bank[TRACK]][(to_bar - 1) * 16 + i] = paste_param
    end
  
  end

end

-- copy *all* pattern steps and parameter pattern values `from_bank` to
-- `to_bank` for current TRACK. **This will overwrite `to_bank`.
function m_grid.copy_bank_pattern(from_bank, to_bank)

for i = 1,16*8 do
    paste_step = pattern[TRACK][from_bank][i]
    pattern[TRACK][to_bank][i] = paste_step

    for p, pattern_ in pairs(param_pattern) do
      paste_param = pattern_[TRACK][from_bank][i]
      param_pattern[p][TRACK][to_bank][i] = paste_param
    end
  
  end
end

-- return parameter `param` value given the `i`th value selected
-- if selecting an already set value, then set to the "0"th (7th) value
-- *ONLY FOR NUMERIC VALUES*
function m_grid.select_param_value(param, i, current_value)

  -- if selecting already set value (rounding fractions), make "zero" value
  if (param_levels[param][i] - 0.001 <= current_value) and
     (current_value <= param_levels[param][i] + 0.001) then
    
    return param_levels[param][7]
  
  -- otherwise, return that value
  else
    return param_levels[param][i]
  end
end

-- draw 8 sequence bars at row `y` starting at `x_start` on grid
-- only consider the tracks from track_range[1] to track_range[2]
function draw_sequence_bars(x_start, y, track_range)
  local last_bar = 1
  local track_last_bar = 1

  for t = track_range[1],track_range[2] do
    track_last_bar = n_bars(t)
    last_bar = track_last_bar > last_bar and track_last_bar or last_bar
  end

  for bar = 1,8 do
    if bar <= last_bar then
      g:led(x_start - 1 + bar, y, g_brightness.bar_populated)
    else
      g:led(x_start - 1 + bar, y, g_brightness.bar_empty)
    end

    if SEQ_BAR == bar then
      g:led(x_start - 1 + bar, y, g_brightness.bar_active)
    elseif (bar - 1) * 16 < step[TRACK] and step[TRACK] <= bar * 16 then
      g:led(x_start - 1 + bar, y, g_brightness.bar_moving)
    end
  end
end

-- for a "2-dimensional" table (array), get the "column" values
-- `t` is the table, and `col` is the column index.
function array_column(t, col)
  local c = {}
  for i=1,#t do
    table.insert(c, t[i][col])
  end
  return c
end

-- return index of value in table
function index_of(array, value)
  for i, v in ipairs(array) do
      if v == value then
          return i
      end
  end
  return nil
end

-- given a table of tables, find the index of the *first* sub-table containing
-- a value. Otherwise, return nil.
function find(array, value)
  i = nil
  for j=1,#array do
    if tab.contains(array[j], value) then
      i = j
      break
    end
  end
  return i
end

-- take a table of tables, and convert to a single "flattened" table
function flatten(t)
  t_flat = {}
  for i=1,#t do
    for j=1,#t[i] do
      table.insert(t_flat, t[i][j])
    end
  end
  return t_flat
end

return m_grid