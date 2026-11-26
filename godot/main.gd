extends Node2D
## Lily Hop — hold to charge, release to hop. Everything (art + SFX) is generated in code.

const W := 320
const H := 180
const WATER := 132.0
const GRAV := 330.0
const SUNX := 232.0
const SAVE_PATH := "user://lilyhop.save"
const RSPAN := 400.0
const RS := 640.0
const SR := 22050

const FONT := {
	"A":"010101111101101","B":"110101110101110","C":"011100100100011","D":"110101101101110","E":"111100110100111",
	"F":"111100110100100","G":"011100101101011","H":"101101111101101","I":"111010010010111","J":"001001001101010",
	"K":"101101110101101","L":"100100100100111","M":"101111111101101","N":"110101101101101","O":"010101101101010",
	"P":"110101110100100","Q":"010101101110011","R":"110101110101101","S":"011100010001110","T":"111010010010010",
	"U":"101101101101111","V":"101101101101010","W":"101101101111010","X":"101101010101101","Y":"101101010010010",
	"Z":"111001010100111","0":"111101101101111","1":"010110010010111","2":"110001010100111","3":"110001010001110",
	"4":"101101111001001","5":"111100110001110","6":"011100111101111","7":"111001010010010","8":"111101111101111",
	"9":"111101111001110","!":"010010010000010","?":"110001010000010",".":"000000000000010",":":"000010000010000",
	"-":"000000111000000","+":"000010111010000","'":"010010000000000",",":"000000000010100"," ":"000000000000000",
	"/":"001001010100100","(":"010100100100010",")":"010001001001010"}
const SKY := ["#140b2b","#24123f","#3d1a55","#5e2163","#86306a","#b0456b","#d8636a","#f2886a","#ffb071"]
const BAYER := [0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5]
const WCOL := ["#3b2b6b","#33255e","#2b1f52","#241a46","#1d153a","#171030"]
const DEATH := ["FROG.EXE STOPPED WORKING","GLUB GLUB GLUB","THAT PAD HAD TRUST ISSUES","SWIMMING? NEVER HEARD OF IT",
	"FROG FORGOT HE CAN SWIM","SPLASH ZONE: 1 FROG","THE FISH SAY HI","SKILL ISSUE (RIBBIT)","HE WAS TOO YOUNG","GRAVITY: 1  FROG: 0"]
const QUIPS := {2:"THE POND WOKE UP",3:"PADS ARE MOVING?!",4:"SINKING EVEN FASTER",5:"FROG MODE: SWEATY",6:"IT'S GETTING DARK..."}

class Frog:
	var x := 60.0
	var y := 131.0
	var vx := 0.0
	var vy := 0.0
	var state := "sit"
	var pad = null
	var charge := 0.0
	var sx := 1.0
	var sy := 1.0
	var rot := 0.0
	var ex := 1
	var ey := 0
	var blink_t := 2.0
	var blink := 0.0
	var throat := 0.0
	var throat_t := 0.0
	var idle := 0.0
	var tongue = null
	var teeter := 0.0
	var max_hold := 0.0
	var sweat := false
	var prev_y := 0.0

var pads: Array = []
var flies: Array = []
var parts: Array = []
var texts: Array = []
var rings: Array = []
var frog: Frog
var game := {}
var cam_x := 0.0
var shake := 0.0
var hit := 0.0
var T := 0.0
var night_v := 0.0
var cricket_t := 2.0
var best_s := 0
var best_x := 0.0
var muted := false

var off := Vector2.ZERO
var ga := 1.0
var _cc := {}
var P := {}
var sky_tex: ImageTexture
var vig_tex: ImageTexture
var stars: Array = []
var clouds: Array = []
var bg_flies: Array = []
var ripples: Array = []
var reeds: Array = []

var SFX := {}
var players: Array = []
var player_i := 0
var charge_player: AudioStreamPlayer

# ---------------------------------------------------------------- setup
func _ready() -> void:
	randomize()
	for k in ["o:#14301a","d:#2f8a3a","g:#5cc94e","h:#a6ef74","b:#f1f7b5","w:#ffffff","k:#141414","m:#3a1020","p:#ff8fa8","t:#ff4f7b"]:
		var s: PackedStringArray = k.split(":")
		P[s[0]] = Color(s[1])
	_build_sky()
	_build_vignette()
	for i in 70:
		stars.append({"x":randi_range(0, W-1),"y":randi_range(0, 84),"ph":randf()*TAU,"sp":randf_range(1,4)})
	for i in 5:
		clouds.append({"x":i*80+randf()*40,"y":randi_range(22,70),"w":randi_range(22,44)})
	for i in 22:
		bg_flies.append({"x":randf()*W,"y":randf_range(70,WATER-4),"ph":randf()*TAU,"sp":randf_range(0.5,1.5)})
	for i in 46:
		var y := float(randi_range(int(WATER)+3, H-1))
		ripples.append({"x":randf()*RSPAN,"y":y,"l":randi_range(3,11),"p":0.6+(y-WATER)/48.0*0.7,"a":randf_range(0.3,0.8),"v":randf_range(-3,3)})
	for i in 26:
		reeds.append({"x":randf()*RS,"h":randi_range(10,29),"head":randf()<0.6})
	_build_audio()
	_load_best()
	reset("title")

func cc(h: String) -> Color:
	if not _cc.has(h):
		_cc[h] = Color(h)
	return _cc[h]

func _build_sky() -> void:
	var img := Image.create(W, int(WATER), false, Image.FORMAT_RGBA8)
	var cols: Array = []
	for s in SKY:
		cols.append(Color(s))
	var bh := WATER / float(SKY.size() - 1)
	for y in int(WATER):
		var f := y / bh
		var i := int(floor(f))
		var fr := f - i
		for x in W:
			var th: float = (BAYER[(y & 3) * 4 + (x & 3)] + 0.5) / 16.0
			var ci: int = min(SKY.size() - 1, i + 1 if fr > th else i)
			img.set_pixel(x, y, cols[ci])
	sky_tex = ImageTexture.create_from_image(img)

func _build_vignette() -> void:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var c := Vector2(W / 2.0, H / 2.0)
	for y in H:
		for x in W:
			var d := Vector2(x, y).distance_to(c)
			var t := clampf((d - H * 0.4) / (H * 0.6), 0.0, 1.0)
			img.set_pixel(x, y, Color(0.02, 0.0, 0.06, 0.6 * t))
	vig_tex = ImageTexture.create_from_image(img)

# ---------------------------------------------------------------- audio (SFX only, no music)
func _tone(f0: float, f1: float, d: float, type: String = "square", v: float = 0.1, delay: float = 0.0) -> Dictionary:
	return {"f0":f0,"f1":f1,"d":d,"type":type,"v":v,"delay":delay}

func _noise(d: float, v: float = 0.3, freq: float = 1200.0, delay: float = 0.0) -> Dictionary:
	return {"f0":freq,"f1":freq*0.25,"d":d,"type":"noise","v":v,"delay":delay}

func _synth(list: Array, loop: bool = false) -> AudioStreamWAV:
	var total := 0.0
	for p in list:
		total = max(total, p.delay + p.d + 0.03)
	var n := int(total * SR)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for p in list:
		var start := int(p.delay * SR)
		var length := int(p.d * SR)
		var phase := 0.0
		var lp := 0.0
		for i in length:
			if start + i >= n:
				break
			var k := float(i) / length
			var gain: float = p.v if loop else p.v * pow(0.0001 / p.v, k)
			var freq: float = p.f0 * pow(p.f1 / p.f0, k)
			var s := 0.0
			if p.type == "noise":
				var a := 1.0 - exp(-TAU * freq / SR)
				lp += a * (randf() * 2.0 - 1.0 - lp)
				s = lp * 2.0
			else:
				phase = fmod(phase + freq / SR, 1.0)
				match p.type:
					"sine": s = sin(TAU * phase)
					"square": s = 1.0 if phase < 0.5 else -1.0
					"triangle": s = 4.0 * abs(phase - 0.5) - 1.0
					"sawtooth": s = 2.0 * phase - 1.0
			buf[start + i] += s * gain
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(clampf(buf[i] * 1.4, -1.0, 1.0) * 32767.0))
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = SR
	st.stereo = false
	st.data = bytes
	if loop:
		st.loop_mode = AudioStreamWAV.LOOP_FORWARD
		st.loop_begin = 0
		st.loop_end = n
	return st

func _build_audio() -> void:
	SFX.jump = _synth([_tone(220,600,0.14,"triangle",0.2), _noise(0.06,0.08,3000)])
	SFX.land = _synth([_tone(170,70,0.1,"sine",0.35), _noise(0.08,0.12,900)])
	SFX.fly = _synth([_tone(1200,1600,0.06,"square",0.05), _tone(1800,2300,0.08,"square",0.05,0.05)])
	var g := []
	for i in 4:
		var f: float = [880.0,1109.0,1319.0,1760.0][i]
		g.append(_tone(f,f*1.01,0.12,"square",0.06,i*0.05))
	SFX.gold = _synth(g)
	SFX.perfect = _synth([_tone(523,523,0.08,"square",0.06), _tone(785,785,0.12,"square",0.06,0.06)])
	SFX.splash = _synth([_noise(0.6,0.5,2400), _tone(300,50,0.4,"sine",0.3), _noise(0.3,0.25,600,0.15)])
	var cr := []
	for i in 4:
		cr.append(_tone(140-i*6,110-i*6,0.05,"sawtooth",0.1,i*0.055))
	cr.append(_tone(180,250,0.09,"square",0.07,0.25))
	SFX.croak = _synth(cr)
	var wb := []
	for i in 3:
		wb.append(_tone(560 if i % 2 else 400, 500 if i % 2 else 350, 0.07, "triangle", 0.12, i*0.08))
	SFX.wobble = _synth(wb)
	var lv := cr.duplicate()
	for i in 4:
		var f2: float = [523.0,659.0,784.0,1047.0][i]
		lv.append(_tone(f2,f2,0.1,"triangle",0.1,0.35+i*0.07))
	SFX.level = _synth(lv)
	SFX.glub = _synth([_tone(300,520,0.08,"sine",0.25), _tone(250,460,0.08,"sine",0.25,0.16), _tone(220,420,0.08,"sine",0.2,0.32)])
	SFX.nooo = _synth([_tone(520,180,0.55,"triangle",0.14)])
	SFX.cricket = _synth([_tone(4300,4200,0.025,"square",0.012), _tone(4300,4200,0.025,"square",0.012,0.06), _tone(4300,4200,0.025,"square",0.012,0.12)])
	var bs := []
	for i in 4:
		var f3: float = [784.0,988.0,1175.0,1568.0][i]
		bs.append(_tone(f3,f3,0.14,"square",0.06,i*0.09))
	SFX.best = _synth(bs)
	SFX.charge = _synth([_tone(180,180,1.0,"triangle",0.05)], true)
	for i in 10:
		var pl := AudioStreamPlayer.new()
		add_child(pl)
		players.append(pl)
	charge_player = AudioStreamPlayer.new()
	charge_player.stream = SFX.charge
	add_child(charge_player)

func sfx(name: String, pitch: float = 1.0) -> void:
	if muted:
		return
	var pl: AudioStreamPlayer = players[player_i]
	player_i = (player_i + 1) % players.size()
	pl.stream = SFX[name]
	pl.pitch_scale = pitch
	pl.play()

func start_charge() -> void:
	if muted:
		return
	charge_player.pitch_scale = 1.0
	charge_player.play()

func stop_charge() -> void:
	charge_player.stop()

# ---------------------------------------------------------------- save
func _load_best() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				best_s = int(d.get("s", 0))
				best_x = float(d.get("x", 0.0))

func _save_best() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"s":best_s,"x":best_x}))

# ---------------------------------------------------------------- world
func diff() -> Dictionary:
	var L: int = game.level
	return {"sink":maxf(0.85, 2.6-(L-1)*0.22), "gmin":12.0+L*3, "gmax":minf(100.0, 40.0+L*8),
		"wmin":maxf(15.0, 30.0-L*2), "wmax":maxf(22.0, 44.0-L*2.5), "move":(minf(0.55, 0.18*(L-2)) if L >= 3 else 0.0)}

func add_pad(cx: float, w: float, mv: float = 0.0) -> Dictionary:
	var p := {"cx":cx,"base":cx,"w":w,"y":WATER-1,"sink":0.0,"dip":0.0,"timer":0.0,"started":false,"gone":false,
		"mv":mv,"ms":randf_range(1,1.8),"ph":randf()*TAU,"flower":randf()<0.3,"dx":0.0}
	pads.append(p)
	return p

func gen_pads() -> void:
	var last: Dictionary = pads[pads.size()-1]
	while last.base + last.w/2.0 < cam_x + W + 160:
		var d := diff()
		var w := roundf(randf_range(d.wmin, d.wmax))
		var gap := randf_range(d.gmin, d.gmax)
		var cx: float = last.base + last.w/2.0 + gap + w/2.0
		var np := add_pad(cx, w, randf_range(8,18) if randf() < d.move else 0.0)
		var mid: float = (last.base + last.w/2.0 + cx - w/2.0) / 2.0
		if gap > 22 and randf() < 0.75:
			var gold := gap > 50 and randf() < 0.4
			flies.append({"x":mid+randf_range(-6,6),"y":WATER-(randf_range(48,58) if gold else randf_range(16,42)),"gold":gold,"ph":randf()*TAU,"taken":false})
		last = np

func reset(mode: String) -> void:
	pads = []; flies = []; parts = []; texts = []; rings = []
	game = {"mode":mode,"started":false,"score":0,"combo":0,"t":0.0,"level":1,"banner":null,"over_t":0.0,"line":"","new_best":false,"max_x":60.0,"pop":0.0,"glubbed":false}
	var p := add_pad(60, 50)
	p.flower = true
	frog = Frog.new()
	frog.y = WATER - 1
	frog.pad = p
	frog.blink_t = randf_range(1,3)
	cam_x = frog.x - 90
	gen_pads()

func add_text(x: float, y: float, s: String, col: String, sc: int = 1) -> void:
	texts.append({"x":x,"y":y,"s":s,"col":cc(col),"sc":sc,"t":0.0})

func add_score(n: int) -> void:
	game.score += n
	game.pop = 1.0

func drops(x: float, y: float, n: int, spd: float = 1.0) -> void:
	for i in n:
		parts.append({"x":x+randf_range(-3,3),"y":y,"vx":randf_range(-60,60)*spd,"vy":randf_range(-130,-30)*spd,"g":420.0,
			"life":randf_range(0.4,0.9),"col":cc(["#a9d8ff","#7fb8ff","#ffffff","#c7b8ff"].pick_random()),"s":2 if randf()<0.3 else 1})

func sparkle(x: float, y: float, n: int, gold: bool) -> void:
	for i in n:
		var a := randf()*TAU
		var v := randf_range(20,90)
		var c: String = (["#ffd23f","#fff3a0","#ffffff","#ff9f3f"] if gold else ["#fff3a0","#ffffff","#d8ff8a"]).pick_random()
		parts.append({"x":x,"y":y,"vx":cos(a)*v,"vy":sin(a)*v,"g":40.0,"life":randf_range(0.3,0.7),"col":cc(c),"s":2 if gold and randf()<0.4 else 1})

# ---------------------------------------------------------------- actions
func jump() -> void:
	var f := frog
	var c := f.charge
	stop_charge()
	f.vx = 42 + c*125
	f.vy = -(85 + c*115)
	f.state = "air"
	f.sx = 0.7; f.sy = 1.35
	var p: Dictionary = f.pad
	f.pad = null
	p.dip = 2.0
	drops(f.x, WATER, 5, 0.6)
	sfx("jump", 1.0 + c*0.6)
	if not game.started:
		game.started = true
		p.started = true
		p.timer = diff().sink
	f.charge = 0.0; f.max_hold = 0.0; f.sweat = false

func land(p: Dictionary) -> void:
	var f := frog
	f.state = "sit"; f.pad = p; f.vx = 0; f.vy = 0
	f.sx = 1.45; f.sy = 0.62; f.rot = 0; f.idle = 0
	p.dip = 2.5
	if not p.started:
		p.started = true
		p.timer = diff().sink
	var o: float = abs(f.x - p.cx) / (p.w/2.0)
	var pts := 1
	if o < 0.22:
		game.combo += 1
		pts += game.combo
		add_text(f.x, f.y-24, "PERFECT X%d" % game.combo if game.combo > 1 else "PERFECT!", "#9bff8a")
		sfx("perfect", pow(1.06, min(game.combo, 12)))
		hit = 0.05
		shake = max(shake, 2.0)
		sparkle(f.x, f.y-4, 8, false)
	else:
		game.combo = 0
		if o > 0.7:
			f.teeter = 0.75
			add_text(f.x, f.y-24, ["WHOA!","OOP-","YIKES","CLOSE ONE"].pick_random(), "#ffd36b")
			sfx("wobble")
		elif randf() < 0.25:
			add_text(f.x, f.y-24, ["BOING","NICE","HOP!","SPLOT"].pick_random(), "#ffffff")
	add_score(pts)
	sfx("land")
	drops(f.x, WATER, 6, 0.5)
	rings.append({"x":f.x,"r":2.0,"life":0.6})

func collect(fl: Dictionary) -> void:
	fl.taken = true
	var g: bool = fl.gold
	add_score(10 if g else 3)
	add_text(fl.x, fl.y-8, "+10 GOLD!" if g else "+3", "#ffd23f" if g else "#fff6a0", 2 if g else 1)
	sfx("gold" if g else "fly")
	sparkle(fl.x, fl.y, 20 if g else 8, g)
	if g:
		hit = 0.07
		shake = max(shake, 3.0)

func die() -> void:
	var f := frog
	stop_charge()
	f.state = "dead"
	game.mode = "dying"; game.over_t = 0.0
	hit = 0.14; shake = 8.0
	sfx("splash")
	drops(f.x, WATER, 40, 1.4)
	rings.append({"x":f.x,"r":2.0,"life":0.9})
	rings.append({"x":f.x,"r":0.0,"life":1.2})
	f.vy = 30; f.vx *= 0.2
	game.combo = 0
	game.line = DEATH.pick_random()
	if game.score > best_s:
		best_s = game.score
		best_x = game.max_x
		game.new_best = true
		_save_best()

# ---------------------------------------------------------------- input
func down() -> void:
	if game.mode == "over" or (game.mode == "dying" and game.over_t > 0.6):
		reset("play")
	if game.mode == "dying":
		return
	if game.mode == "title":
		game.mode = "play"
	if frog.state == "sit":
		frog.state = "charge"
		frog.charge = 0.0
		frog.max_hold = 0.0
		start_charge()

func up() -> void:
	if frog and frog.state == "charge":
		jump()

func toggle_mute() -> void:
	muted = not muted
	stop_charge()

func _input(e: InputEvent) -> void:
	if e is InputEventKey and not e.echo:
		if e.keycode in [KEY_SPACE, KEY_UP, KEY_W, KEY_ENTER]:
			if e.pressed:
				down()
			else:
				up()
		elif e.keycode == KEY_M and e.pressed:
			toggle_mute()
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			var p := get_local_mouse_position()
			if p.x > W - 40 and p.y < 16 and p.y >= 0:
				toggle_mute()
				return
			down()
		else:
			up()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		up()

# ---------------------------------------------------------------- update
func damp(k: float, dt: float) -> float:
	return 1.0 - pow(k, dt)

func _process(delta: float) -> void:
	var dt := minf(delta, 0.033)
	T += dt
	if hit > 0:
		hit -= dt
	else:
		update(dt)
	queue_redraw()

func update(dt: float) -> void:
	var f := frog
	for p in pads:
		if p.mv > 0:
			var nx: float = p.base + sin(T*p.ms + p.ph) * p.mv
			p.dx = nx - p.cx
			p.cx = nx
		else:
			p.dx = 0.0
		p.dip *= pow(0.0005, dt)
		if p.started and not p.gone:
			p.timer -= dt
			if p.timer < 0.9 and p.timer > 0 and randf() < dt*14:
				parts.append({"x":p.cx+randf_range(-p.w/2.0, p.w/2.0),"y":WATER+3,"vx":0.0,"vy":-18.0,"g":0.0,"life":0.35,"col":cc("#b9c8ff"),"s":1})
			if p.timer <= 0:
				p.sink += dt*14
				if p.sink > 7:
					p.gone = true
	if f.state == "sit" or f.state == "charge":
		var p: Dictionary = f.pad
		f.x += p.dx
		f.y = p.y + p.sink + p.dip*0.6
		if p.gone:
			stop_charge()
			f.state = "air"; f.vx = 0; f.vy = 10; f.pad = null
			add_text(f.x, f.y-24, "NOOO!", "#ff8a8a")
			sfx("nooo")
	var k := damp(0.0005, dt)
	if f.state == "charge":
		f.charge = minf(1.0, f.charge + dt*1.15)
		f.sx = lerpf(f.sx, 1 + f.charge*0.28, minf(1.0, k*2))
		f.sy = lerpf(f.sy, 1 - f.charge*0.32, minf(1.0, k*2))
		charge_player.pitch_scale = (180.0 + f.charge*520.0 + (sin(T*40)*40.0 if f.charge >= 1 else 0.0)) / 180.0
		if f.charge >= 1:
			f.max_hold += dt
			if f.max_hold > 0.7 and not f.sweat:
				f.sweat = true
				add_text(f.x, f.y-26, "!!", "#ff7a7a")
			if randf() < dt*5:
				parts.append({"x":f.x+5,"y":f.y-14,"vx":randf_range(10,35),"vy":-45.0,"g":220.0,"life":0.6,"col":cc("#8fd3ff"),"s":1})
	else:
		f.sx = lerpf(f.sx, 1, k)
		f.sy = lerpf(f.sy, 1, k)
	if f.state == "sit":
		f.idle += dt
		if f.idle > 2.4:
			f.idle = -1.5
			f.throat_t = 0.6
			sfx("croak")
			if game.mode == "play":
				add_text(f.x, f.y-24, ["RIBBIT","CROAK","...HOP?","BRRRP"].pick_random(), "#c8ffb0")
	if f.throat_t > 0:
		f.throat_t -= dt
		f.throat = abs(sin((0.6 - f.throat_t)*PI*5))
	else:
		f.throat = 0.0
	if f.teeter > 0:
		f.teeter = maxf(0, f.teeter - dt)
	f.blink_t -= dt
	if f.blink_t < 0:
		f.blink = 0.12
		f.blink_t = randf_range(1.5, 4)
	if f.blink > 0:
		f.blink -= dt

	if f.state == "air":
		f.prev_y = f.y
		f.vy += GRAV*dt
		f.x += f.vx*dt
		f.y += f.vy*dt
		f.rot = clampf(f.vy/600.0, -0.35, 0.4)
		if f.vy > 0:
			for p in pads:
				if p.gone:
					continue
				var top: float = p.y + p.sink
				if f.prev_y <= top + 0.5 and f.y >= top and abs(f.x - p.cx) <= p.w/2.0 + 1.5:
					f.y = top
					land(p)
					break
		if f.state == "air":
			var mx := f.x + 1
			var my := f.y - 7
			for fl in flies:
				if fl.taken:
					continue
				var fy: float = fl.y + sin(T*3 + fl.ph)*2
				var d := Vector2(fl.x - mx, fy - my).length()
				if d < 7:
					collect(fl)
				elif f.tongue == null and d < 26 and fl.x > f.x - 6:
					f.tongue = {"fl":fl,"t":0.0}
			if f.y > WATER + 3:
				die()
	elif f.state != "dead":
		f.rot = sin(T*25)*0.32*(f.teeter/0.75) if f.teeter > 0 else lerpf(f.rot, 0, k)
	if f.tongue != null:
		var tg: Dictionary = f.tongue
		tg.t += dt/0.16
		if tg.t >= 0.5 and not tg.fl.taken:
			collect(tg.fl)
		if tg.t >= 1:
			f.tongue = null

	var tx := 1
	var ty := 0
	if f.state == "air":
		var bf = null
		var bd := 70.0
		for fl in flies:
			if fl.taken:
				continue
			var dd := Vector2(fl.x - f.x, fl.y - f.y).length()
			if dd < bd:
				bd = dd
				bf = fl
		if bf != null:
			tx = int(sign(bf.x - f.x))
			ty = int(sign(bf.y - (f.y - 8)))
		else:
			ty = 1 if f.vy > 60 else -1
	elif f.state == "charge":
		ty = -1
	elif f.state == "dead":
		tx = int(round(sin(T*2)))
	if f.teeter > 0:
		tx = int(round(sin(T*18)))
		ty = -1
	f.ex = clampi(tx, -1, 1)
	f.ey = clampi(ty, -1, 1)

	if f.state == "dead":
		f.vy = lerpf(f.vy, 18, damp(0.1, dt))
		f.y += f.vy*dt
		f.x += f.vx*dt
		f.vx *= pow(0.05, dt)
	if game.mode == "dying":
		game.over_t += dt
		if game.over_t > 0.75 and not game.glubbed:
			game.glubbed = true
			sfx("glub")
			add_text(f.x+8, WATER-14, "GLUB", "#a9d8ff")
		if game.over_t > 1.05:
			game.mode = "over"
			if game.new_best:
				sfx("best")
	elif game.mode == "over":
		game.over_t += dt

	if game.mode == "play" and game.started:
		game.t += dt
		if game.t >= game.level*10:
			game.level += 1
			game.banner = {"t":2.4,"a":"LEVEL %d" % game.level,"b":QUIPS.get(game.level, "GOOD LUCK LOL")}
			sfx("level")
			shake = max(shake, 3.0)
	if f.state != "dead":
		cam_x += (f.x - 90 - cam_x) * damp(0.003, dt)
	game.max_x = maxf(game.max_x, f.x)
	gen_pads()
	pads = pads.filter(func(p): return p.cx + p.w > cam_x - 60 or is_same(p, f.pad))
	flies = flies.filter(func(fl): return fl.x > cam_x - 30 and (not fl.taken or (f.tongue != null and is_same(f.tongue.fl, fl))))
	for p in parts:
		p.vy += p.g*dt
		p.x += p.vx*dt
		p.y += p.vy*dt
		p.life -= dt
	parts = parts.filter(func(p): return p.life > 0 and not (p.g > 100 and p.y > WATER + 4 and p.vy > 0))
	for t in texts:
		t.t += dt
		t.y -= dt*(60.0 if t.t < 0.15 else 14.0)
	texts = texts.filter(func(t): return t.t < 1.1)
	for r in rings:
		r.r += dt*28
		r.life -= dt
	rings = rings.filter(func(r): return r.life > 0)
	if game.banner != null:
		game.banner.t -= dt
		if game.banner.t <= 0:
			game.banner = null
	game.pop = maxf(0, game.pop - dt*4)
	night_v += (minf(0.6, (game.level - 1)*0.09) - night_v)*dt*0.6
	cricket_t -= dt
	if cricket_t < 0:
		sfx("cricket")
		cricket_t = randf_range(1.5, 4)

# ---------------------------------------------------------------- drawing helpers
func rect(x: float, y: float, w: float, h: float, c: Color) -> void:
	if w <= 0 or h <= 0:
		return
	draw_rect(Rect2(roundf(x) + off.x, roundf(y) + off.y, roundf(w), roundf(h)), Color(c.r, c.g, c.b, c.a*ga))

func draw_str(s: String, x: float, y: float, sc: int, col: Color) -> void:
	for i in s.length():
		var g: String = FONT.get(s[i], FONT["?"])
		for r in 5:
			for c in 3:
				if g[r*3 + c] == "1":
					rect(x + i*4*sc + c*sc, y + r*sc, sc, sc, col)

func txt(s, x: float, y: float, sc: int = 1, col: Color = Color.WHITE, al: String = "l") -> void:
	var t := str(s).to_upper()
	var w := t.length()*4*sc - sc
	if al == "c":
		x -= w/2.0
	elif al == "r":
		x -= w
	x = roundf(x); y = roundf(y)
	draw_str(t, x + sc, y + sc, sc, cc("#1a0f2e"))
	draw_str(t, x, y, sc, col)

func ell(cx: float, top: float, w: float, h: int, c_top: Color, c_mid: Color, c_bot: Color) -> void:
	for r in h:
		var t := ((r + 0.5)/h)*2.0 - 1.0
		var half := roundf(w/2.0*sqrt(1.0 - t*t))
		var c := c_top if r < h*0.35 else (c_mid if r < h*0.7 else c_bot)
		rect(cx - half, top + r, half*2, 1, c)

func disc(cx: float, cy: float, r: int, col: Color, max_y: float) -> void:
	for dy in range(-r, r + 1):
		var y := cy + dy
		if y >= max_y:
			break
		var h := roundf(sqrt(r*r - dy*dy))
		rect(cx - h, y, h*2, 1, col)

func S(k: String, x: float, y: float, w: float, h: float) -> void:
	var c: Color = P[k]
	draw_rect(Rect2(x - 8, y - 16, w, h), Color(c.r, c.g, c.b, c.a*ga))

func SC(c: Color, x: float, y: float, w: float, h: float) -> void:
	draw_rect(Rect2(x - 8, y - 16, w, h), c)

func draw_frog_sprite(o: Dictionary) -> void:
	var g: Color = o.body
	if not o.air:
		S("o",0,10,4,4); S("o",12,10,4,4); S("d",1,11,2,2); S("d",13,11,2,2)
		S("o",0,13,5,2); S("o",11,13,5,2); S("d",1,13,3,1); S("d",12,13,3,1)
	else:
		S("o",2,11,3,5); S("o",11,11,3,5); S("d",3,12,1,3); S("d",12,12,1,3); S("d",2,15,3,1); S("d",11,15,3,1)
	S("o",3,5,10,9); S("o",2,6,12,7); S("o",1,7,14,5)
	SC(g,3,6,10,7); SC(g,2,7,12,5)
	S("h",4,6,3,1); S("h",3,7,1,1)
	S("b",5,10,6,3); S("b",4,11,8,1)
	if o.throat > 0.05:
		var r := roundf(o.throat*2)
		S("o",5-r,9,6+2*r,4+r); S("p",6-r,10,4+2*r,2+r); S("w",6-r,10,1,1)
	S("o",2,1,6,6); S("o",8,1,6,6)
	if o.blink:
		SC(g,3,2,4,4); SC(g,9,2,4,4); S("o",3,4,4,1); S("o",9,4,4,1)
	else:
		S("w",3,2,4,4); S("w",9,2,4,4)
		var px: int = 4 + o.ex
		var py: int = 3 + o.ey
		S("k",px,py,2,2); S("k",px+6,py,2,2)
	match o.mouth:
		"open":
			S("m",6,8,4,2); S("t",7,9,2,1)
		"o":
			S("m",7,8,2,2)
		_:
			S("o",5,9,6,1); S("o",4,8,1,1); S("o",11,8,1,1)
	S("p",3,8,1,1); S("p",12,8,1,1)

func draw_eyes(x: float, y: float, ex: int, ey: int, blink: bool) -> void:
	x = roundf(x); y = roundf(y)
	rect(x-6, y, 6, 6, P.o); rect(x, y, 6, 6, P.o)
	if blink:
		rect(x-5, y+1, 4, 4, P.g); rect(x+1, y+1, 4, 4, P.g)
		rect(x-5, y+3, 4, 1, P.o); rect(x+1, y+3, 4, 1, P.o)
		return
	rect(x-5, y+1, 4, 4, P.w); rect(x+1, y+1, 4, 4, P.w)
	rect(x-4+ex, y+2+ey, 2, 2, P.k); rect(x+2+ex, y+2+ey, 2, 2, P.k)

func wrapv(v: float, span: float) -> float:
	return fmod(fmod(v, span) + span, span)

# ---------------------------------------------------------------- scene parts
func draw_sun() -> void:
	var cx := SUNX
	var cy := roundf(94 + night_v*60)
	var r := 16
	ga = 0.08; disc(cx, cy, r+9, cc("#ffb36b"), WATER)
	ga = 0.16; disc(cx, cy, r+4, cc("#ffc27a"), WATER)
	ga = 1.0
	disc(cx, cy, r, cc("#ffcf73"), WATER)
	disc(cx, cy-3, r-5, cc("#fff0b0"), WATER)
	for s in [[5,1],[9,1],[12,2],[15,2]]:
		var y: float = cy + s[0]
		if y < WATER:
			var h: float = minf(s[1], WATER - y)
			var src := Rect2(cx - r - 1, y, 2*r + 2, h)
			draw_texture_rect_region(sky_tex, Rect2(src.position + off, src.size), src)

func draw_cloud(c: Dictionary) -> void:
	var span := W + 100.0
	var x := roundf(wrapv(c.x - cam_x*0.06 - T*2.5, span) - 50)
	var y: float = c.y
	var w: float = c.w
	rect(x+2, y+3, w-4, 1, cc("#8e3a6e"))
	var m := cc("#d0607a")
	rect(x, y, w, 3, m); rect(x+4, y-2, w-10, 2, m); rect(x+8, y-4, roundf(w*0.35), 2, m)
	var hl := cc("#f08a7a")
	rect(x+5, y-2, roundf(w*0.3), 1, hl); rect(x+9, y-4, roundf(w*0.2), 1, hl)

func draw_pad(p: Dictionary) -> void:
	if p.sink > 9:
		return
	var warn: bool = p.started and p.timer < 0.9 and not p.gone
	var jit := 0.0
	if warn and p.timer > 0:
		jit = -1.0 if randf() < 0.5 else 1.0
	var cx := roundf(p.cx - cam_x) + jit
	var w: float = p.w
	var h := maxi(4, int(roundf(w*0.17)))
	var top := roundf(p.y + p.sink + p.dip)
	if cx < -40 or cx > W + 40:
		return
	var flash := warn and int(floor(T*14)) % 2 == 0
	var c_t := cc("#e6dd72") if flash else cc("#7ad66b")
	var c_m := cc("#b8ad4c") if flash else cc("#45a84f")
	var c_b := cc("#2a7038")
	ga = 0.3; rect(cx - roundf(w/2) + 2, top + h, w - 4, 1, cc("#0d0820")); ga = 1.0
	var o := cc("#173d22")
	ell(cx, top-1, w+2, h+2, o, o, o)
	ell(cx, top, w, h, c_t, c_m, c_b)
	rect(cx, top + floor(h/2.0) - 1, roundf(w*0.3), 1, c_b)
	rect(cx - roundf(w*0.28), top + floor(h/2.0), roundf(w*0.2), 1, c_b)
	var nx := cx + roundf(w*0.2)
	rect(nx, top-1, 3, 2, cc("#2b1f52")); rect(nx+1, top+1, 2, 1, cc("#2b1f52"))
	if p.flower:
		var q := cx - roundf(w*0.28)
		rect(q-1, top-2, 3, 2, cc("#ff8fc0")); rect(q, top-3, 1, 1, cc("#ff8fc0")); rect(q, top-2, 1, 1, cc("#ffe066"))

func draw_fly(fl: Dictionary, wx: float, wy: float) -> void:
	var x := roundf(wx - cam_x)
	var y := roundf(wy)
	if x < -10 or x > W + 10:
		return
	var g: bool = fl.gold
	var f := 0.6 + 0.4*sin(T*8 + fl.ph)
	var c := cc("#ffd23f") if g else cc("#fff3a0")
	ga = 0.15*f; rect(x-4, y-4, 9, 9, c)
	ga = 0.3*f; rect(x-2, y-2, 5, 5, c)
	ga = 1.0; rect(x-1, y-1, 3, 3, c); rect(x, y, 1, 1, Color.WHITE)
	var wf := int(floor(T*20)) % 2
	var wc := Color(1, 1, 1, 0.75)
	rect(x-2, y-2-wf, 1, 1, wc); rect(x+2, y-2-wf, 1, 1, wc)
	if g:
		var sp := cc("#fff8d0")
		if int(floor(T*6)) % 2:
			rect(x, y-6, 1, 3, sp); rect(x, y+4, 1, 3, sp); rect(x-6, y, 3, 1, sp); rect(x+4, y, 3, 1, sp)
		else:
			for d in [[3,3],[4,4],[-3,3],[-4,4],[3,-3],[4,-4],[-3,-3],[-4,-4]]:
				rect(x + d[0], y + d[1], 1, 1, sp)

func draw_frog() -> void:
	var f := frog
	var mouth := "smile"
	if f.state == "air":
		mouth = "open" if (f.tongue != null or f.vy < 0) else ("o" if f.vy > 150 else "smile")
	elif f.state == "charge" and f.charge >= 1:
		mouth = "o"
	if f.teeter > 0:
		mouth = "o"
	var body: Color = P.g
	if f.max_hold > 0:
		body = P.g.lerp(cc("#e0623a"), minf(1.0, f.max_hold*0.8))
	var jx := 0.0
	if f.state == "charge" and f.charge >= 1:
		jx = -1.0 if randf() < 0.5 else 1.0
	if f.state == "air":
		var hgt := WATER - f.y
		if hgt > 2:
			ga = clampf(0.35 - hgt/200.0, 0.08, 0.35)
			var sw := roundf(clampf(10 - hgt/8.0, 3, 10))
			rect(f.x - cam_x - sw/2.0, WATER + 1, sw, 1, cc("#0d0820"))
			ga = 1.0
	draw_set_transform(Vector2(roundf(f.x - cam_x + jx), roundf(f.y)) + off, f.rot, Vector2(f.sx, f.sy))
	draw_frog_sprite({"ex":f.ex,"ey":f.ey,"blink":f.blink > 0 and f.state != "air","mouth":mouth,
		"air":f.state == "air" or f.state == "dead","throat":f.throat,"body":body})
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if f.tongue != null:
		var tg: Dictionary = f.tongue
		var e: float = tg.t*2 if tg.t < 0.5 else (1 - tg.t)*2
		var mx := f.x + 1
		var my := f.y - 7*f.sy
		var fy: float = tg.fl.y + sin(T*3 + tg.fl.ph)*2
		var ex: float = mx + (tg.fl.x - mx)*e
		var ey: float = my + (fy - my)*e
		var n := int(ceil(Vector2(ex - mx, ey - my).length()))
		for i in n + 1:
			var t := float(i)/n if n > 0 else 0.0
			rect(mx + (ex - mx)*t - cam_x, my + (ey - my)*t, 2, 2, P.t)
		rect(ex - cam_x - 1, ey - 1, 3, 3, P.p)
		if tg.t >= 0.5:
			draw_fly(tg.fl, ex, ey)

# ---------------------------------------------------------------- render
func _draw() -> void:
	off = Vector2.ZERO
	if shake > 0:
		off = Vector2(roundf(randf_range(-shake, shake)), roundf(randf_range(-shake, shake)*0.6))
	shake = maxf(0, shake - 0.5)
	ga = 1.0
	draw_texture(sky_tex, off)
	rect(-10, -10, W + 20, 10, cc("#140b2b"))
	draw_sun()
	for c in clouds:
		draw_cloud(c)
	var far := cc("#4a2259")
	for x in range(-8, W + 8):
		var wx := x + cam_x*0.15
		var t := roundf(WATER - 22 - 10*sin(wx*0.013) - 6*sin(wx*0.031 + 1.3) - 3*sin(wx*0.071))
		rect(x, t, 1, WATER - t, far)
	rect(-8, WATER - 16, W + 16, 16, Color(1, 0.59, 0.55, 0.10))
	var mid := cc("#2a1240")
	for x in range(-8, W + 8):
		var wx := x + cam_x*0.35
		var t := roundf(WATER - 5 - (5 + 4*sin(wx*0.021) + 7*abs(sin(wx*0.11)) + 3*abs(sin(wx*0.37))))
		rect(x, t, 1, WATER - t, mid)
	if night_v > 0.005:
		rect(-8, -8, W + 16, WATER + 8, Color(0.03, 0.016, 0.11, night_v))
	for s in stars:
		var a: float = night_v*1.6*(0.5 + 0.5*sin(T*s.sp + s.ph))
		if a < 0.03:
			continue
		ga = minf(1.0, a)
		rect(s.x, s.y, 1, 1, Color.WHITE)
	ga = 1.0
	var fc := cc("#fff3a0")
	for b in bg_flies:
		var x := roundf(wrapv(b.x - cam_x*0.4 + sin(T*b.sp + b.ph)*6, W))
		var y := roundf(b.y + cos(T*b.sp*0.8 + b.ph)*4)
		var a := (0.3 + 0.7*(0.5 + 0.5*sin(T*3 + b.ph)))*(0.35 + night_v)
		ga = a*0.25; rect(x-1, y-1, 3, 3, fc)
		ga = minf(1.0, a); rect(x, y, 1, 1, fc)
	ga = 1.0
	for i in WCOL.size():
		var y0 := WATER + i*8
		rect(-8, y0, W + 16, (H - y0 + 8) if i == WCOL.size() - 1 else 8.0, cc(WCOL[i]))
	var scy := 94 + night_v*60
	for r in range(0, H - int(WATER), 2):
		var w := maxf(0, 18 - r*0.35 - (scy - 94)*0.2)*(0.6 + 0.4*sin(T*3 + r*0.7))
		if w < 1:
			continue
		ga = (1 - night_v)*(1 - r/(H - WATER))*0.9
		rect(SUNX - w/2.0 + sin(T*2 + r*0.5)*2, WATER + r + 1, w, 1, cc("#ffd08a") if r < 10 else cc("#e88a6a"))
	ga = 1.0
	var rc := cc("#5d4b9e")
	for rp in ripples:
		ga = rp.a
		rect(wrapv(rp.x - cam_x*rp.p + T*rp.v, RSPAN) - 40, rp.y, rp.l, 1, rc)
	ga = 1.0
	if best_x > 120:
		var x := roundf(best_x - cam_x)
		if x > -20 and x < W + 20:
			rect(x, WATER - 30, 1, 32, cc("#d9c8ff"))
			for i in 5:
				rect(x + 1, WATER - 30 + i + roundf(sin(T*6 + i*0.8)), 8 - i, 1, cc("#ff5d7a"))
			txt("BEST", x, WATER - 38, 1, cc("#ffd6e0"), "c")
	for p in pads:
		draw_pad(p)
	for fl in flies:
		if not fl.taken:
			draw_fly(fl, fl.x, fl.y + sin(T*3 + fl.ph)*2)
	if frog.state != "dead" or frog.y < WATER + 16:
		draw_frog()
	rect(-8, WATER + 4, W + 16, H - WATER + 4, Color(0.12, 0.08, 0.24, 0.6))
	var gl := cc("#8a78d0")
	for i in 14:
		ga = 0.4 + 0.3*sin(T*2 + i)
		rect(wrapv(i*37 - cam_x + T*6, W + 40) - 20, WATER + 4, 4 + (i % 3)*2, 1, gl)
	ga = 1.0
	if game.mode == "dying" or game.mode == "over":
		var ot: float = game.over_t
		if ot > 0.5:
			var rise := minf(1.0, (ot - 0.5)*5)
			draw_eyes(frog.x - cam_x, WATER - 1 - roundf(rise*4) + roundf(sin(T*4)), int(round(sin(T*1.7))), int(round(sin(T*2.3)*0.6)), int(floor(T*3)) % 5 == 0)
			if int(floor(T*2)) % 3 == 0 and randf() < 0.15:
				parts.append({"x":frog.x + randf_range(-4,4),"y":WATER+3,"vx":0.0,"vy":-25.0,"g":0.0,"life":0.4,"col":cc("#b9c8ff"),"s":1})
	var ringc := cc("#c7b8ff")
	for r in rings:
		ga = minf(1.0, r.life*1.4)
		var n := maxi(8, int(roundf(r.r*2)))
		for i in n:
			var a := float(i)/n*TAU
			rect(r.x - cam_x + cos(a)*r.r, WATER + 2 + sin(a)*r.r*0.22, 1, 1, ringc)
	for p in parts:
		ga = minf(1.0, p.life*3)
		rect(p.x - cam_x, p.y, p.s, p.s, p.col)
	ga = 1.0
	var reed := cc("#0f0a1a")
	for r in reeds:
		var bx := roundf(wrapv(r.x - cam_x*1.35, RS) - 40)
		if bx < -10 or bx > W + 10:
			continue
		var sw: float = sin(T*1.4 + r.x)*2
		for k in r.h:
			rect(bx + roundf(sw*k/r.h), H - k, 2 if k < r.h*0.5 else 1, 1, reed)
		if r.head:
			rect(bx + roundf(sw) - 1, H - r.h - 5, 3, 6, cc("#3b1d14"))
			rect(bx + roundf(sw), H - r.h - 8, 1, 3, reed)
	for t in texts:
		ga = maxf(0, 1 - (t.t - 0.7)/0.4) if t.t > 0.7 else 1.0
		txt(t.s, t.x - cam_x, t.y, t.sc, t.col, "c")
	ga = 1.0
	var f := frog
	if f.state == "charge":
		var bx := roundf(f.x - cam_x) - 8
		var by := roundf(f.y) - 26
		var c := f.charge
		rect(bx - 1, by - 1, 18, 4, cc("#1a0f2e"))
		rect(bx, by, roundf(16*c), 2, cc("#7cff6b") if c < 0.5 else (cc("#ffd23f") if c < 0.85 else cc("#ff5d5d")))
		var vx := 42 + c*125
		var vy := -(85 + c*115)
		for i in range(1, 8):
			var t := i*0.045
			ga = 1 - i/8.0
			rect(f.x + vx*t - cam_x, f.y - 6 + vy*t + 0.5*GRAV*t*t, 1, 1, Color.WHITE)
		ga = 1.0
	off = Vector2.ZERO
	draw_texture(vig_tex, Vector2.ZERO)
	draw_ui()

func draw_ui() -> void:
	var m: String = game.mode
	txt("MUTE" if muted else "SFX", W - 4, 4, 1, cc("#ff8a8a") if muted else cc("#c8b8ff"), "r")
	if m == "title":
		var s := "LILY HOP"
		var sc := 4
		var x := W/2.0 - (s.length()*16 - 4)/2.0
		for i in s.length():
			var y := 26 + roundf(sin(T*3 + i*0.6)*3)
			draw_str(s[i], x + i*16 + sc, y + sc, sc, cc("#1a0f2e"))
			draw_str(s[i], x + i*16, y, sc, cc("#9bff8a") if i < 4 else cc("#ffd23f"))
		txt("HOLD TO CHARGE - RELEASE TO HOP", W/2.0, 56, 1, cc("#ffe9d0"), "c")
		txt("CATCH FIREFLIES. DON'T SINK.", W/2.0, 65, 1, cc("#ffb3c6"), "c")
		if int(floor(T*2)) % 2:
			txt("TAP OR SPACE", W/2.0, 80, 2, Color.WHITE, "c")
		if best_s > 0:
			txt("BEST %d" % best_s, 4, 4, 1, cc("#ffd23f"))
		return
	txt(game.score, W/2.0, 5, 3 if game.pop > 0.4 else 2, Color.WHITE, "c")
	if game.combo > 1:
		txt("COMBO X%d" % game.combo, W/2.0, 20, 1, cc("#9bff8a"), "c")
	txt("LV %d" % game.level, 4, 4, 1, cc("#c8b8ff"))
	txt("BEST %d" % best_s, 4, 11, 1, cc("#ffd23f"))
	if game.banner != null:
		var b: Dictionary = game.banner
		ga = minf(1.0, minf(b.t*2, (2.4 - b.t)*6))
		txt(b.a, W/2.0, 42, 4 if b.t > 2.2 else 3, cc("#ffd23f"), "c")
		txt(b.b, W/2.0, 62, 1, Color.WHITE, "c")
		ga = 1.0
	if m == "over":
		ga = minf(1.0, game.over_t*4)
		rect(28, 24, W - 56, 92, Color(0.08, 0.04, 0.16, 0.85))
		var bc := cc("#ffb071")
		rect(28, 24, W - 56, 1, bc); rect(28, 115, W - 56, 1, bc); rect(28, 24, 1, 92, bc); rect(W - 29, 24, 1, 92, bc)
		var line: String = game.line
		txt(line, W/2.0, 32, 2 if line.length()*8 < W - 64 else 1, cc("#ffb3c6"), "c")
		txt("SCORE", W/2.0, 48, 1, cc("#c8b8ff"), "c")
		txt(game.score, W/2.0, 56, 3, Color.WHITE, "c")
		txt("BEST %d" % best_s, W/2.0, 77, 1, cc("#ffd23f"), "c")
		if game.new_best and int(floor(T*6)) % 2:
			txt("NEW BEST!", W/2.0, 86, 2, cc("#9bff8a"), "c")
		ga = 1.0
		if int(floor(T*2)) % 2:
			txt("TAP TO HOP AGAIN", W/2.0, 104, 1, Color.WHITE, "c")
