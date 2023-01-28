module main

import rand
import time
import gg
import gx


const (
	block_size 			= 20
	field_height 		= 20
	field_width 		= 10
	tetro_size 			= 4
	win_width				= block_size * field_width
	win_height			= block_size * field_height
	timer_period		= 250 //ms
	text_size				= 24
	limit_tickness	= 3
)

const (
	text_cfg = gx.TextCfg{
		align: .left
		size: text_size
		color: gx.rgb(0,0,0)
	}
	over_cfg = gx.TextCfg{
		align: .left
		size: text_size
		color: gx.white
	}
)

const (
	b_tetros = [
		[66,66,66,66],
		[27,131,72,231],
		[36,231,36,231],
		[63,132,63,132],
		[311,17,223,74],
		[322,71,113,47],
		[1111,9,1111,9]
	]

	colors = [
		gx.rgb(0,0,0),
		gx.rgb(255,242,0),
		gx.rgb(174,0,255),
		gx.rgb(60,255,0),
		gx.rgb(255,0,0),
		gx.rgb(255,180,31),
		gx.rgb(33,66,255),
		gx.rgb(74,198,255),
		gx.rgb(0,170,170)
	]
	background_color = gx.white
	ui_color = gx.rgba(255,0,0,210)
)

struct Block {
mut:
		x int
		y int
}

enum GameState {
	paused
	running
	gameover
}

struct Game {
mut:
	 // score the current game
	 score int
	 // lines of the current game
	 lines int
	 // state of the current game
	 state GameState
	 // Block size in screen dimension
	 block_size int = block_size
	 // Field margin
	 margin int
	 // Position of the current tetro
	 pos_x int
	 pos_y int
	 // Field[y][x] contains the color of the block with (x,y) coordinates
	 // '-1' border is to avoid bounds checking
	 // -1 -1 -1 -1
	 //	-1  0  0 -1
	 // -1  0  0 -1
	 // -1 -1 -1 -1
	 field [][]int
	 // TODO: tetro Tetro
	 tetro []Block
	 // TODO: tetros_cache []Tetros
	 tetros_cache []Block
	 // Index of the current tetro. Refer to its color
	 tetro_idx int
	 // Idem for the next tetro
	 next_tetro_idx int
	 // Index of rotation (0-3)
	 rotation_idx int
	 // gg context for drawing
	 gg &gg.Context = unsafe { nil }
	 font_loaded bool
	 show_ghost bool = true
	 // frame time/counters
	 frame int
	 frame_old int
	 frame_sw time.StopWatch = time.new_stopwatch()
	 second_sw time.StopWatch = time.new_stopwatch()
}

fn remap(v f32, min f32, max f32, new_min f32, new_max f32) f32 {
	return (((v-min)*(new_max - new_min)) / (max - min)) + new_min
}

[if showfps ?]
fn (mut game Game) showfps() {
	game.frame++
	last_frame_ms := f64(game.frame_sw.elapsed().microseconds()) / 1000.0
	ticks := f64(game.second_sw.elapsed().microseconds()) / 1000.0
	if ticks > 999.0 {
		fps := f64(game.frame - game.frame_old) * ticks / 1000.0
		$if debug {
			eprintln('fps: ${fps:5.1f} | last_frame took: ${last_frame_ms:6.3f} | frame: ${game.frame:6} ')
		}
		game.second_sw.restart()
		game.frame_old = game.frame
	}
}

fn frame(mut game Game) {
	if game.gg.frame & 15 == 0 {
		game.update_game_state()
	}
	ws := gg.window_size()
	bs := remap(block_size, 0, win_height, 0, ws.height)
	m := (f32(ws.width) - bs * field_width) * 0.5
	game.block_size = int(bs)
	game.margin = int(m)
	game.frame_sw.restart()
	game.gg.begin()
	game.draw_scene()
	game.showfps()
	game.gg.end()
}
fn main() {
	mut game := &Game{
		gg: &gg.Context{}
	}
	// mut fpath := os.resource_abs_path(os.join_path('assets','RobotoMono-Regular.ttf'))
	// $if android {
	// 	fpath = 'fonts/RobotoMono-Regular.ttf'
	// }
	game.gg = gg.new_context(
		bg_color: gx.white
		width: win_width
		height: win_height
		create_window: true
		window_title: 'V Tetris'
		user_data: game
		frame_fn: frame
		event_fn: on_event,
		//font_path: fpath // wait_events: true
		canvas: 'canvas'
	)

	game.init_game()
	game.gg.run() // Run the render loop in the main thread
}

fn (mut game Game) init_game() {
	game.parse_tetros()
	game.next_tetro_idx = rand.intn(b_tetros.len) or { 0 } // generate the initial next
	game.generate_tetro()
	game.field = []

	// Generate the field, fill it with 0's, add -1's on each edge
	for _ in 0 .. field_height + 2 {
		mut row := [0].repeat(field_width + 2)
		row[0] = -1
		row[field_width + 1] = -1
		game.field << row
	}
	for j in 0 .. field_width + 2 {
		game.field[0][j] = -1
		game.field[field_height + 1][j] = -1
	}
	game.score = 0
	game.lines = 0
	game.state = .running
}

fn (mut game Game) parse_tetros(){
	for b_tetros0 in b_tetros {
		for b_tetro in b_tetros0 {
			for t in parse_binary_tetro(b_tetro){
				game.tetros_cache << t
			}
		}
	}
}

fn (mut game Game) update_game_state() {
	if game.state == .running {
		game.move_tetro()
		game.delete_completed_lines()
	}
}

fn (mut game Game) draw_ghost(){
	if game.state != .gameover && game.show_ghost {
		pos_y := game.move_ghost()
		for i in 0..tetro_size {
			tetro := game.tetro[i]
			game.draw_block_color(pos_y * tetro.y, game.pos_x + tetro.x, gx.rgba(125,125,125,40))
		}
	}
}

fn (game Game) move_ghost() int {
	mut pos_y := game.pos_y
	mut end := false
	for !end {
		for block in game.tetro {
			y := block.y + pos_y + 1
			x := block.x + game.pos_x
			if game.field[y][x] != 0 {
				end = true
				break
			}
		}
		pos_y++
	}
	return pos_y - 1
}

fn (mut game Game) move_tetro() bool {
	// Check each block is current in tetro
	for block in game.tetro {
		y := block.y + game.pos_y + 1
		x := block.x + game.pos_x

		// Reacher the bottom of screen or another block?
		if game.field[y][x] != 0 {
			// the new tetro has no space to drop => end of the game
			if game.pos_y < 2 {
				game.state = .gameover
				return false
			}
			// Drop it and generate a new one
			game.drop_tetro()
			game.generate_tetro()
			return false
		}
	}
	game.pos_y++
	return true
}
fn (mut game Game) move_right(dx int) bool {
	// Reached left or right edge or another tetro
	for i in 0..tetro_size {
		tetro := game.tetro[i]
		y := tetro.y + game.pos_y
		x := tetro.x + game.pos_x + dx
		if game.field[y][x] != 0 {
			// do not move
			return false
		}
	}
	game.pos_x += dx
	return true
}
fn (mut game Game) delete_completed_lines() {
	for y := field_height; y >= 1; y--{
		game.delete_completed_line(y)
	}
}
fn (mut game Game) delete_completed_line(y int) {
	for x := 1; x <= field_width; x++ {
		if game.field[y][x] == 0 {
			return
		}
	}
	game.score += 10
	game.lines++
	// Move everything down by 1 position
	for yy := y -1; yy >= 1; yy-- {
		for x := 1; x <= field_width; x++ {
			game.field[yy + 1][x] = game.field[yy][x]
		}
	}
}

// Place a new tetro on top
fn (mut game Game) generate_tetro(){
	game.pos_y = 0
	game.pos_x = field_width / 2 - tetro_size / 2
	game.tetro_idx = game.next_tetro_idx
	game.next_tetro_idx = rand.intn(b_tetros.len) or { 0 }
	game.rotation_idx =0
	game.get_tetro()
}

// Get the right tetro from the cache
fn (mut game Game) get_tetro(){
	idx := game.tetro_idx * tetro_size * tetro_size + game.rotation_idx * tetro_size
	mut tetros := []Block{}
	for tetro in game.tetros_cache[idx..idx + tetro_size]{
		tetros << Block{tetro.x, tetro.y}
	}
	game.tetro = tetros
}

// TODO mut
fn (mut game Game) drop_tetro(){
	for i in 0..tetro_size {
		tetro := game.tetro[i]
		x := tetro.x + game.pos_x
		y := tetro.y + game.pos_y
		// remember the color for each block
		game.field[y][x] = game.tetro_idx + 1
	}
}

fn (mut game Game) draw_tetro(){
	for i in 0..tetro_size {
		tetro := game.tetro[i]
		game.draw_block(game.pos_y + tetro.y, game.pos_x + tetro.x, game.tetro_idx + 1)
	}
}

fn (mut game Game) draw_next_tetro() {
	if game.state != .gameover {
		idx := game.next_tetro_idx * tetro_size * tetro_size
		next_tetro := game.tetros_cache[idx..idx+tetro_size]
		pos_y := 0
		pos_x :=  field_width / 2 - tetro_size / 2
		for i in 0 .. tetro_size {
			block := next_tetro[i]
			game.draw_block_color(pos_y + block.y, pos_x + block.x, gx.rgb(220,220,220))
		}
	}
}

fn (mut game Game) draw_block_color(i int, j int, color gx.Color) {
	game.gg.draw_rect(f32((j-1)*game.block_size) + game.margin, f32((i-1)*game.block_size),f32(game.block_size - 1), f32(game.block_size - 1), color)

}
fn (mut game Game) draw_block(i int, j int, color_idx int) {
	color := if game.state == .gameover {gx.gray} else { colors[color_idx]}
	game.draw_block_color(i,j,color)
}

fn (mut game Game) draw_field() {
	for i := 1; i <= field_height + 1; i++ {
		for j := 1; j <= field_width + 1; j++ {
			if game.field[i][j] > 0 {
				game.draw_block(i, j, game.field[i][j])
			}
		}
	}
}

fn (mut game Game) draw_ui() {
	ws := gg.window_size()
	textsize := int(remap(text_size, 0, win_width, 0, ws.width))
	game.gg.draw_text(1,10,game.score.str(),text_cfg)
	lines := game.lines.str()
	game.gg.draw_text(ws.width - lines.len * textsize, 10, lines, text_cfg)
	if game.state == .gameover {
		game.gg.draw_rect(0, ws.height / 2 - textsize, ws.width, 5 * textsize, ui_color)
		game.gg.draw_text(1, ws.height / 2 + 0 * textsize, 'Game Over', over_cfg)
		game.gg.draw_text(1, ws.height / 2 + 2 * textsize, 'SPACE to restart', text_cfg)
	} else if game.state == .paused {
		game.gg.draw_rect(0, ws.height / 2 - textsize, ws.width, 5 * textsize, ui_color)
		game.gg.draw_text(1, ws.height / 2 + 0 * textsize, 'Game Paused', over_cfg)
		game.gg.draw_text(1, ws.height / 2 + 2 * textsize, 'SPACE to resume', text_cfg)
	}
}

fn (mut game Game) draw_scene() {
	game.draw_ghost()
	game.draw_next_tetro()
	game.draw_tetro()
	game.draw_field()
	game.draw_ui()
}

fn parse_binary_tetro( t_ int) []Block {
	mut t := t_
  mut res := [Block{}, Block{}, Block{}, Block{}]
	mut cnt := 0
	horizontal := t == 9 // special case for horizontal line
	ten_power := [1000, 100, 10, 1]
	for i := 0; i <= 3; i++ {
		//get ith digit of t
		p := ten_power[i]
		mut digit := t / p

		t %= p

		// convert the digit to binary
		for j := 3; j >= 0; j-- {
			bin := digit % 2
			digit /= 2
			if bin == 1 || (horizontal && i == tetro_size - 1) {
				res[cnt].x = j
				res[cnt].y = i
				cnt++
			}
		}
	}
	return res
}

fn on_event(e &gg.Event, mut game Game) {
	// println('code=$e.char_code')
	if e.typ == .key_down {
		game.key_down(e.key_code)
	}
}


fn (mut game Game) rotate_tetro() {
	old_rotation_idx := game.rotation_idx
	game.rotation_idx++
	if game.rotation_idx == tetro_size {
		game.rotation_idx = 0
	}
	game.get_tetro()
	if !game.move_right(0) {
		game.rotation_idx = old_rotation_idx
		game.get_tetro()
	}
	if game.pos_x < 0 {

	}
}

fn (mut game Game) key_down(key gg.KeyCode) {
	match key {
		.escape {
			game.gg.quit()
		}
		.space {
			if game.state == .running {
				game.state = .paused
			} else if game.state == .paused {
				game.state = .running
			} else if game.state == .gameover {
				game.init_game()
				game.state == .running
			}
		}
		else {}
	}
	if game.state != .running {
		return
	}
	match key {
		.up {
			game.rotate_tetro()
		}
		.left {
			game.move_right(-1)
		}
		.right{
			game.move_right(1)
		}
		.down{
			game.move_tetro()
		}
		.d {
			for game.move_tetro() {

			}
		}
		.g {
			game.show_ghost = !game.show_ghost
		}
		else {}
 	}
}