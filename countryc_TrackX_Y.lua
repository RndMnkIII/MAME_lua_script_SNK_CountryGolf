-- countryc_TrackX_Y.lua
-- Show Trackball data for axis X and Y.
-- Author: @RndMnkIII
-- Version: 1.0 (08/08/2022)

-- How to use: place a copy of countryc_TrackX_Y.lua file inside main mame folder and 
-- execute from command line: mame countryc -window -autoboot_script countryc_TrackX_Y.lua
-- CAUTION: ALL ARRAYS ARE 1-BASED INDEX

-- input manager
INP = manager.machine.input 

RETRIG_STOP = 0

-- screen object reference
SCR = manager.machine.screens[":screen"]
SCR_W = SCR.width
SCR_H = SCR.height
TRANSPARENCY_LV = 0X90
frm_counter = 0
print(emu.app_name() .. " " .. emu.app_version())
print(string.format("SCR_W: %d SCR_H: %d", SCR_W, SCR_H))

-- Track X,Y values
m_track = {}
m_track[1] = {}
m_track[1].x = 0;
m_track[1].y = 0;
m_track[2] = {}
m_track[2].x = 0;
m_track[2].y = 0;
m_track_sel = 1;

SPRAM = manager.machine.devices[":maincpu"].spaces["program"]

-- C300 trackball selection, C100 trackBallX, C200 trackBallY
trackSelcb = SPRAM:install_write_tap(0xc300,0xc300,"trackSel_CB", function (offset, data, mask) m_track_sel = (data & 0x1) + 1; end)
trackXcb = SPRAM:install_read_tap(0xc100,0xc100,"trackX_CB", function (offset, data, mask) m_track[m_track_sel].x = ~(data & 0x7f) & 0x7f; end)
trackYcb = SPRAM:install_read_tap(0xc200,0xc200,"trackY_CB", function (offset, data, mask) m_track[m_track_sel].y = data & 0x7f; end)

function Draw_TrackballXY_box()
    if not manager.machine.paused then frm_counter = frm_counter + 1 end

	SCR:draw_text(0, 0, string.format("Track1: %01d X:%03d Y:%03d", m_track_sel, m_track[1].x, m_track[1].y), 0xffffaa00) --in MAME the x,y order was reversed respect to the schematics
	box_color = (TRANSPARENCY_LV<<24) +  (200 << 16) + (100 << 8)
	SCR:draw_box(m_track[1].x-5, m_track[1].y-5, m_track[1].x+5,  m_track[1].y+5,box_color, box_color2)
	SCR:draw_text(128, 0, string.format("Track2: %01d X:%03d Y:%03d", m_track_sel, m_track[2].x, m_track[2].y), 0xffaa00ff) --in MAME the x,y order was reversed respect to the schematics
	box_color2 = (TRANSPARENCY_LV<<24) + (200 << 8) + 100
	SCR:draw_box(m_track[2].x-5+128, m_track[2].y-5, m_track[2].x+5+128,  m_track[2].y+5,box_color2, box_color)
    return
end

emu.register_frame_done(Draw_TrackballXY_box, "frame")