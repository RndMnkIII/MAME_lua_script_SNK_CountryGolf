-- tnkiii_sprites_show.lua
-- Show SPRITES boxes with data info overimposed the MAME screen output
-- Author: @RndMnkIII
-- Version: 1.0 (26/02/2022)

-- How to use: place a copy of aso_sprites_show.lua file inside main mame folder and 
-- execute from command line: mame countryc -window -autoboot_script countryc_TrackX_Y.lua
-- CAUTION: ALL ARRAYS ARE 1-BASED INDEX

-- input manager
INP = manager.machine.input 

RETRIG_STOP = 0

-- screen object reference
SCR = manager.machine.screens[":screen"]
SCR_W = SCR.width
SCR_H = SCR.height
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

CRAM_START = 0X0
CRAM_END = 0X3FF
CRAM_ENTRY_SIZE = 2 --2 bytes
--
--CRAM  = manager.machine.devices[":palette"].spaces["program"]

SPRAM = manager.machine.devices[":maincpu"].spaces["program"]
SPRAM_START = 0xd000
SPRAM_END   = 0xd7ff
SPRAM_ENTRY_SIZE = 4 --Each sprite uses 4 bytes for attributes

--Assign a color for each sprite (0-49)
SPR_COLORS = {}
SPR_NUM_SPRITES = 50
SPR_WIDTH = 16
SPR_HEIGHT = 16

SPR_TRANSPARENCY = 0X90
idx = 1
for i=255,0,-2 do
    SPR_COLORS[idx] = {}
    SPR_COLORS[idx].r = math.random(0,255)
    SPR_COLORS[idx].g = math.random(0,255)
    SPR_COLORS[idx].b = math.random(0,255)
    idx = idx + 1
    --print(string.format("%02X-%02X-%02X", SPR_COLORS[color_idx].r, SPR_COLORS[color_idx].g, SPR_COLORS[color_idx].b))
end

--Sprites array
SPRITES_TABLE = {}
max_sprites_on_scanline = 0
m_sp16_scrolly = 0
m_sp16_scrollx = 0
m_bg_scrolly = 0
m_bg_scrollx = 0
m_screen_flip = 0



-- C300 trackball selection, C100 trackBallX, C200 trackBallY
trackSelcb = SPRAM:install_write_tap(0xc300,0xc300,"trackSel_CB", function (offset, data, mask) m_track_sel = (data & 0x1) + 1; end)
trackXcb = SPRAM:install_read_tap(0xc100,0xc100,"trackX_CB", function (offset, data, mask) m_track[m_track_sel].x = ~(data & 0x7f) & 0x7f; end)
trackYcb = SPRAM:install_read_tap(0xc200,0xc200,"trackY_CB", function (offset, data, mask) m_track[m_track_sel].y = data & 0x7f; end)

-- In schematics C800 -> MSB, C900 -> FSX, CA00 -> FSY, CB00 -> B1SX, CC00 -> B1SY
bg_scroy = SPRAM:install_write_tap(0xcb00, 0xcb00, "w_bg_scrolly", function (offset, data, mask) m_bg_scrolly = (m_bg_scrolly & ~0xff) | data; return data; end)
bg_scrox = SPRAM:install_write_tap(0xcc00, 0xcc00, "w_bg_scrollx", function (offset, data, mask) m_bg_scrollx = (m_bg_scrollx & ~0xff) | data; return data; end)
spr16_scroy = SPRAM:install_write_tap(0xc900, 0xc900, "w_sp16_scrolly", function (offset, data, mask) m_sp16_scrolly = (m_sp16_scrolly & ~0xff) | data; return data; end)
spr16_scrox = SPRAM:install_write_tap(0xca00, 0xca00, "w_sp16_scrollx", function (offset, data, mask) m_sp16_scrollx = (m_sp16_scrollx & ~0xff) | data; return data; end)
video_attr = SPRAM:install_write_tap(0xc800, 0xc800, "w_video_attrib",  function (offset, data, mask) m_bg_scrollx   = (m_bg_scrollx   & 0xff) | ((data & 0x02) << 7); m_bg_scrolly   = (m_bg_scrolly   & 0xff) | ((data & 0x10) << 4); m_screen_flip = (data & 0x80) >> 7; m_sp16_scrolly = (m_sp16_scrolly & 0xff) | ((data & 0x08) << 5); m_sp16_scrollx = (m_sp16_scrollx & 0xff) | ((data & 0x01) << 8); return data; end)
--print(string.format("Sprite Scroll Y: %d Sprite Scroll X: %d", m_sp16_scrolly, m_sp16_scrollx))

m_yscroll_mask = 0x1ff
size = 16

function Read_sprite_data()
    spr_idx = 0
    for i=SPRAM_START,SPRAM_END,SPRAM_ENTRY_SIZE do
        spr_idx = spr_idx + 1
        SPRITES_TABLE[spr_idx] = {}
        sprmem = {}

        for j=1,SPRAM_ENTRY_SIZE,1 do
            sprmem[j] = SPRAM:read_u8(i+j-1) -- adjust for 0 based address offset
        end

        -- tile_number = spriteram[offs+1]
        SPRITES_TABLE[spr_idx].tile_number = sprmem[2]
        SPRITES_TABLE[spr_idx].tile = sprmem[2]
        SPRITES_TABLE[spr_idx].mem = {}
        SPRITES_TABLE[spr_idx].mem = sprmem
        -- attributes  = spriteram[offs+3]
        SPRITES_TABLE[spr_idx].attributes = sprmem[4]
		-- color = attributes & 0xf
        SPRITES_TABLE[spr_idx].color = SPRITES_TABLE[spr_idx].attributes & 0xf 
		-- sx =  xscroll + 301 - size - spriteram[offs+2]

        SPRITES_TABLE[spr_idx].sx2 = sprmem[3] + ((SPRITES_TABLE[spr_idx].attributes & 0x80) << 1)
        SPRITES_TABLE[spr_idx].sy2 = sprmem[1] + ((SPRITES_TABLE[spr_idx].attributes & 0x10) << 4)

        SPRITES_TABLE[spr_idx].sx = m_sp16_scrollx + 301 - size - sprmem[3]
		-- sy = -yscroll + 7 - size + spriteram[offs]
        SPRITES_TABLE[spr_idx].sy =  (-m_sp16_scrolly) + 7 - size + sprmem[1]
		-- sx += (attributes & 0x80) << 1
        SPRITES_TABLE[spr_idx].sx = SPRITES_TABLE[spr_idx].sx + ((SPRITES_TABLE[spr_idx].attributes & 0x80) << 1)
		--SPRITES_TABLE[spr_idx].sx = 89 - size - SPRITES_TABLE[spr_idx].sx
		-- sy += (attributes & 0x10) << 4
        SPRITES_TABLE[spr_idx].sy = SPRITES_TABLE[spr_idx].sy + ((SPRITES_TABLE[spr_idx].attributes & 0x10) << 4)
		--SPRITES_TABLE[spr_idx].sy = 262 - 16 - SPRITES_TABLE[spr_idx].sy
		-- xflip = 0
        SPRITES_TABLE[spr_idx].xflip = 0
		-- yflip = 0
        SPRITES_TABLE[spr_idx].yflip = 0
        
        --because gfx number is 512
        SPRITES_TABLE[spr_idx].tile_number = SPRITES_TABLE[spr_idx].tile_number | ((SPRITES_TABLE[spr_idx].attributes & 0x40) << 2)
        SPRITES_TABLE[spr_idx].tile_number = SPRITES_TABLE[spr_idx].tile_number | ((SPRITES_TABLE[spr_idx].attributes & 0x20) << 4)

        SPRITES_TABLE[spr_idx].sx = SPRITES_TABLE[spr_idx].sx & 0x1ff
        SPRITES_TABLE[spr_idx].sy = SPRITES_TABLE[spr_idx].sy & m_yscroll_mask

        --if (sx > 512-size) sx -= 512
        if ( SPRITES_TABLE[spr_idx].sx > (512-size) ) then
            SPRITES_TABLE[spr_idx].sx = SPRITES_TABLE[spr_idx].sx - 512
        end

        -- --if (sy > (m_yscroll_mask+1)-size) sy -= (m_yscroll_mask+1)
        if ( SPRITES_TABLE[spr_idx].sy > ((m_yscroll_mask+1)-size) ) then
            SPRITES_TABLE[spr_idx].sy = SPRITES_TABLE[spr_idx].sy - (m_yscroll_mask+1)
        end
    end
    --assert (spr_idx == SPR_NUM_SPRITES, "spr_idx no es igual a SPR_NUM_SPRITES" )
    return
end

function Draw_TrackballXY_box()
    --Read_sprite_data()
    
    --Show frame counter
    --SCR:draw_text(0, 16, string.format("Frm: %05d",frm_counter), 0xffffaa00)
    --SCR:draw_text(0, 0, string.format("B1SX:%03x B1SY:%03x", m_bg_scrolly, m_bg_scrollx), 0xffffaa00) --in MAME the x,y order was reversed respect to the schematics
    --SCR:draw_text(0, 8, string.format("FSX :%03x FSY :%03x", m_sp16_scrolly, m_sp16_scrollx), 0xffffaa00)
    --SCR:draw_text(0, 8, string.format(" SX2:%03d  SY2:%03d SX:%03d SY:%03d", SPRITES_TABLE[36].sx2, SPRITES_TABLE[36].sy2, SPRITES_TABLE[36].sx, SPRITES_TABLE[36].sy), 0xffffaa00)
    --SCR:draw_text(0, 48, string.format("Frm: %05d",frm_counter), 0xffffaa00)
    --print(string.format("Sprite Scroll Y: %d Sprite Scroll X: %d", m_sp16_scrolly, m_sp16_scrollx))
    
    -- if (frm_counter == 1200) and not manager.machine.paused then 
    --     print("*** Frame 1200 ***")
    -- end
    
    --for i=1,SPR_NUM_SPRITES,1 do
        -- spr_px = SPRITES_TABLE[i].sx
        -- spr_py = SPRITES_TABLE[i].sy - 8 --hack
        -- spr_px2 = spr_px +  SPR_WIDTH
        -- spr_py2 = spr_py + SPR_HEIGHT
        -- spr_mx = (spr_px2 - spr_px)//2 + spr_px
        -- spr_my = (spr_py2 - spr_py)//2 + spr_py
        
        --spr_color = (SPR_TRANSPARENCY<<24) +  (SPR_COLORS[i].r << 16) + (SPR_COLORS[i].g << 8) + SPR_COLORS[i].b
        --spr_color = (SPR_TRANSPARENCY<<24) +  (200 << 16) + (SPR_COLORS[i].g << 8) + SPR_COLORS[i].b
        --text_str = string.format("%03x", SPRITES_TABLE[i].tile_number)
        --text_str = string.format("%d", i)

        -- if (i>=36 and i<=37) then
        --     SCR:draw_box(spr_px, spr_py, spr_px2, spr_py2,spr_color, 0)
        --     --SCR:draw_box(spr_px, spr_py, spr_px2, spr_py2, 0xffff00ff, 0)
        --     SCR:draw_text(spr_px2+2-24, spr_my, text_str, spr_color)
        -- end
        --if (frm_counter > 300) then
            --print(string.format("[Sprite:%d][Tile:%d] PX:%d PY:%d DX:%d DY:%d", i, SPRITES_TABLE[i].tile_number, spr_px, spr_py, spr_px2, spr_py2))
        --end

        --x,y swap
        -- SCR:draw_box(spr_py, spr_px, spr_py2, spr_px2,spr_color, 0)
        -- SCR:draw_text(spr_my, spr_mx, text_str, 0xffff00ff)

        -- (2449 at 61 fps -> 2408 at 60fps)
        --1200
        -- if (frm_counter == 1200) and not manager.machine.paused then 
        --     print(string.format("Tile spr #%02d: x:%04d y:%04d %02x/%04x data[%02x,%02x,%02x,%02x]",i,spr_px,spr_py,SPRITES_TABLE[i].tile,SPRITES_TABLE[i].tile_number,SPRITES_TABLE[i].mem[1],SPRITES_TABLE[i].mem[2],SPRITES_TABLE[i].mem[3],SPRITES_TABLE[i].mem[4]))
        -- end
    --end

    -- if frm_counter == 1200 then 
    --     emu.pause() 
    -- end
    if not manager.machine.paused then frm_counter = frm_counter + 1 end

    -- -  (dash) is KEYCODE_MINUS
    -- - (minus keypad) is KEYCODE_MINUS_PAD
    -- * (multiply keypad) is KEYCODE_ASTERICK
    -- / (divide keypad) is KEYCODE_SLASH_PAD
    -- / (forwardslash) is KEYCODE_SLASH
    -- \ (backslash) is KEYCODE_BACKSLASH; (semi-colon) is KEYCODE_COLON
    -- ` (tick) is KEYCODE_TILDE
    -- . (period) is KEYCODE_STOP
    -- [ (open bracket) is KEYCODE_OPENBRACE
    -- ] (closed bracket) is KEYCODE_CLOSEBRACE
    -- ' (single quote) is KEYCODE_QUOTE

    --WORKS
    -- KEYCODE_LEFT
    
    -- if INP:code_pressed(INP:code_from_token("KEYCODE_STOP")) then

    --     if RETRIG_STOP == 0 then
    --         Cap_spr_data()
    --         --print(string.format("STOP"))
    --     end

    --     if RETRIG_STOP < 5 then
    --         RETRIG_STOP = RETRIG_STOP + 1
    --     else
    --         RETRIG_STOP = 0
    --     end
    -- end
	SCR:draw_text(0, 0, string.format("Track1: %01d X:%03d Y:%03d", m_track_sel, m_track[m_track_sel].x, m_track[m_track_sel].y), 0xffffaa00) --in MAME the x,y order was reversed respect to the schematics
	box_color = (SPR_TRANSPARENCY<<24) +  (200 << 16) + (100 << 8)
	SCR:draw_box(m_track[1].x-5, m_track[1].y-5, m_track[1].x+5,  m_track[1].y+5,box_color, box_color2)
	SCR:draw_text(128, 0, string.format("Track2: %01d X:%03d Y:%03d", m_track_sel, m_track[m_track_sel].x, m_track[m_track_sel].y), 0xffaa00ff) --in MAME the x,y order was reversed respect to the schematics
	box_color2 = (SPR_TRANSPARENCY<<24) + (200 << 8) + 100
	SCR:draw_box(m_track[2].x-5+128, m_track[2].y-5, m_track[2].x+5+128,  m_track[2].y+5,box_color2, box_color)
    return
end

emu.register_frame_done(Draw_TrackballXY_box, "frame")

--function Cap_spr_data()
    -- print(string.format("*** FRAME # %d ***", frm_counter))
    -- for i=1,SPR_NUM_SPRITES,1 do
    --     spr_px = SPRITES_TABLE[i].sx
    --     spr_py = SPRITES_TABLE[i].sy - 8 --hack
    --     print(string.format("[Sprite:%d] [Tile:%03x] PX:%d PY:%d", i, SPRITES_TABLE[i].tile_number, spr_px, spr_py))
    -- end
    -- print("")
--end

-- B