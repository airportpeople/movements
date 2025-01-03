-- user interface
-- i.e., redraw, key, and enc for each page

-- each page should be paired with a grid page
-- "shift" on grid associated with K1
-- E1 changes page
-- each page only uses E/K 2 and 3

-- not sure about this yet ...:
-- grid page change --> affect display page
-- display page change --> NO grid page change

local m_ui = {}

local UI = require "ui"

-----------------------------------------------------------------
-- INIT
-----------------------------------------------------------------

function m_ui.init()
  display = {}
  display[1] = UI.Pages.new(1, 4)  -- sample
  display[2] = UI.Pages.new(2, 1)  -- tape
  display[3] = UI.Pages.new(3, 1)  -- delay

  -- display info in order
  display_names = {'sample', 'tape', 'delay'}
end

-----------------------------------------------------------------
-- NAVIGATION
-----------------------------------------------------------------

-- main navigation bar
function m_ui.draw_nav(header)
  y = 5  -- default text hight
  glyph_buffer = 2

  for i = 1,#display_names do
    x = (i - 1) * glyph_buffer
    screen.move(x, y)
    screen.level(i == DISPLAY_ID and 15 or 2)
    screen.text("|")
  end

  -- current display header
  screen.move_rel(glyph_buffer * 2, 0)

  if display_names[DISPLAY_ID] == 'sample' then
    screen.text(TRACK .. " • " .. 
                BANK .. " • " .. 
                header)
  else
    screen.text(header)
  end

  screen.stroke()
end

-----------------------------------------------------------------
-- SAMPLE
-----------------------------------------------------------------

-- 1: TRACK POOL SELECTION --------------------------------------

function m_ui.sample_1_redraw()
  screen.aa(0)

  m_ui.draw_nav(SAMPLE ~= nil and params:string('sample_' .. SAMPLE) or "-")

  list_buffer = 8
  max_samples = 5
  text_width = 10

  local text = nil

  screen.move(60, 10)
  screen.line(60, 50)
  screen.stroke()

  -- track_cue
  screen.level(5)
  for i=1, math.min(#track_pool_cue[TRACK][BANK], max_samples) do
    screen.move(62, 10 + list_buffer * i)
    text = params:string('sample_' .. track_pool_cue[TRACK][BANK][i])
    if string.len(text) > text_width then
      text = string.sub(text, 1, text_width) .. " ..."
    end
    screen.text(text)
  end

  if #track_pool_cue[TRACK][BANK] > max_samples then
    screen.move(84, 54)
    screen.text_center(" . . . ")
  end
  
  -- track_pool
  screen.level(15)
  for i=1, math.min(#track_pool[TRACK], max_samples) do
    screen.move(1, 10 + list_buffer * i)
    text = params:string('sample_' .. track_pool[TRACK][i])
    if string.len(text) > text_width then
      text = string.sub(text, 1, text_width) .. " ..."
    end
    screen.text(text)
  end

  if #track_pool[TRACK] > max_samples then
    screen.move(30, 54)
    screen.text_center(" . . . ")
  end

  -- indicate bank folder for this track
  local folder = bank_folders[BANK]

  bank_text = "K2 to load bank"
  bank_text = folder ~= nil and folder or bank_text

  screen.level(5)
  screen.move(60, 61)
  screen.text_center(" -- " .. bank_text .. " --")

end

function m_ui.sample_1_key(n,z)

  if n == 2 and z == 1 then
    m_sample:load_bank(BANK)
  end

end

function m_ui.sample_1_enc(n,d)
  -- 
end

-- 2: TRACK PARAMS --------------------------------------------

function m_ui.sample_2_redraw()
  screen.aa(0)

  m_ui.draw_nav(SAMPLE ~= nil and params:string('sample_' .. SAMPLE) or "-")

  screen.level(12)

  -- p = params:get('track_' .. TRACK .. '_' .. PARAM)
  -- lookup = params:lookup_param('track_' .. TRACK .. '_' .. PARAM)
  -- min_ = lookup['controlspec']['minval']
  -- max_ = lookup['controlspec']['maxval']

  -- if PARAM == 'pan' then
  --   center = 0
  -- elseif tab.contains({'rate', 'scale'}, PARAM) then
  --   center = 1
  -- else
  --   center = nil
  -- end

  -- m_ui.draw_slider({10, 18}, min_, max_, p, 101, center)
  -- screen.stroke()

  -- current parameter
  screen.move(30, 36)
  screen.text_center(PARAM)
  screen.move(30, 50)

  if PARAM == 'filter' then
    screen.text_center(params:string('track_' .. TRACK .. '_filter_freq'))
    screen.move(30, 58)
    screen.text_center(params:string('track_' .. TRACK .. '_filter_type'))
  
  -- TAG: param 10 ... add here.
  elseif tab.contains({'amp', 'pan', 'filter'}, PARAM) then
    screen.text_center(params:string('track_' .. TRACK .. '_' .. PARAM))
  end
  
  -- extra parameter
  screen.move(90, 36)
  screen.text_center('noise')
  screen.move(90, 50)
  screen.text_center(params:string('track_' .. TRACK .. '_noise'))

end

function m_ui.sample_2_key(n,z)
  -- 
end

function m_ui.sample_2_enc(n,d)
  if n == 2 then
    params:delta('track_' .. TRACK .. '_' .. PARAM, d)
  elseif n == 3 then
    params:delta('track_' .. TRACK .. '_noise', d)
  end
  screen_dirty = true
end

-- 3: SAMPLE  ------------------------------------------------------
function m_ui.sample_3_redraw()
  local header = SAMPLE ~= nil and params:string('sample_' .. SAMPLE) or "-"

  m_ui.draw_nav(header)

  waveform_view:update()
  waveform_view:redraw()

  screen.stroke()
end

function m_ui.sample_3_key(n,z)
  waveform_view:key(n, z)
  screen_dirty = true
end

function m_ui.sample_3_enc(n,d)
  waveform_view:enc(n, d)
  screen_dirty = true
end

-- 4: FILTER AMP --------------------------------------------------
function m_ui.sample_4_redraw()
  m_ui.draw_nav(SAMPLE ~= nil and params:string('sample_' .. SAMPLE) or "-")

  screen.aa(1)
  filter_amp_view:redraw()

  screen.stroke()
end

function m_ui.sample_4_key(n,z)
  -- for fine tuning
  if n == 1 then
    if z == 1 then
      Timber.shift_mode = true
    else
      Timber.shift_mode = false
    end
  end

  filter_amp_view:key(n, z)
  screen_dirty = true
end

function m_ui.sample_4_enc(n,d)
  filter_amp_view:enc(n, d)
  screen_dirty = true
end


-----------------------------------------------------------------
-- TAPE
-----------------------------------------------------------------

-- 1: MAIN ------------------------------------------------------
recording = 0

function m_ui.tape_1_redraw()
  m_ui.draw_nav(
    TRACK .. " • " .. 
    PARTITION .. " • " ..
    util.round(SLICE[1], 0.1) .. " - " .. util.round(SLICE[2], 0.1)
  )

  screen.move(64, 50)

  if recording == 1 then
    screen.text_center('recording voice 1 ...')
  else
    screen.text_center('STOPPED recording voice 1 ...')
  end

  screen.stroke()
end

function m_ui.tape_1_key(n,z)
  if n == 3 and z == 1 then
    recording = recording ~ 1

    if recording == 1 then
      softcut.rec(1, 1)
    else
      softcut.rec(1, 0)
    end

    screen_dirty = true
  end
end

function m_ui.tape_1_enc(n,d)
  print('recording encoder')
end

-- function m_ui.draw_partition(partition)
--   screen.move(1, 12)
--   screen.line(128, 12)
--   screen.stroke()


-- end

-- function m_ui.draw_waveform(voice)

--   -- display buffer
--   screen.level(6)
--   local x_pos = 0
--   for i, s in ipairs(waveform_samples[track_focus]) do
--     local height = util.round(math.abs(s) * (14 / wave_gain[track_focus]))
--     screen.move(util.linlin(0, 128, 5, 123, x_pos), 36 - height)
--     screen.line_rel(0, 2 * height)
--     screen.stroke()
--     x_pos = x_pos + 1
--   end
--   -- update buffer
--   if track[track_focus].rec == 1 then
--     render_slice()
--   end

-- end

-- 2: TRACK PARAMS ----------------------------------------------

-- TODO: second param option (analogous to noise) is overdub (pre)


-----------------------------------------------------------------
-- DELAY
-----------------------------------------------------------------

-- 1: MAIN ------------------------------------------------------
function m_ui.delay_1_redraw()
  m_ui.draw_nav("delay 1")
  screen.move(64, 32)
  screen.text_center('delay!')

  if rec_toggle == 1 then
    screen.move(64, 50)
    screen.text_center('oh yeaaah!')
  end

  screen.stroke()
end

function m_ui.delay_1_key(n,z)
  if n == 3 and z == 1 then
    rec_toggle = rec_toggle ~ 1
    screen_dirty = true
  end
end

function m_ui.delay_1_enc(n,d)
  print('recording encoder')
end

-----------------------------------------------------------------
-- UTILITY
-----------------------------------------------------------------

-- draw a minimal "slider", with a circle indicating the value `v`, and
-- two vertical lines on either side indicating `min` and `max` values.
-- `middle_left` is the location of the far left (middle) of the slider.
-- `center` divides the slider into two partitions. (e.g., 0 for pan).
-- |`v`| is in [`min`, `max`] with `v` < 0 indicating a right-bound line.
function m_ui.draw_slider(middle_left, min, max, v, width, center)

  height = 10
  width = width == nil and 64 or width
  middle_right = {middle_left[1] + width, middle_left[2]}

  top = middle_left[2] - (height - 1) / 2  -- highest position of slider bound

  v_abs = math.abs(v)
  v_x = util.linlin(min, max, middle_left[1], middle_right[1], v_abs)
  
  if center then
    div_x = util.linlin(min, max, middle_left[1], middle_right[1], center)
    screen.move(div_x, top)
    screen.line(div_x, top + 2)
    screen.move(div_x, top + height - 3)
    screen.line(div_x, top + height - 1)

    -- value
    k = v_abs > center and 1 or 0  -- adjust "starting" point for big pixels
    screen.move(div_x + k, middle_left[2])
    screen.line(v_x + k, middle_left[2])

  elseif v > 0 then
    -- left bound
    screen.move(middle_left[1], top)
    screen.line(middle_left[1], top + 2)
    screen.move(middle_left[1], top + height - 3)
    screen.line(middle_left[1], top + height - 1)

    -- value
    screen.move(middle_left[1], middle_left[2])
    screen.line(v_x, middle_left[2])

  elseif v < 0 then
    -- right bound
    screen.move(middle_left[1] + width, top)
    screen.line(middle_left[1] + width, top + 2)
    screen.move(middle_left[1] + width, top + height - 3)
    screen.line(middle_left[1] + width, top + height - 1)

    -- value
    screen.move(middle_left[1] + width, middle_left[2])
    screen.line(v_x, middle_left[2])

  end

end

return m_ui