import random
import math

def generate_palette():
    # Return 4 colors: transparent, primary, secondary, highlight
    h = random.random()
    colors = ['#00000000']
    for _ in range(3):
        color = "#{:06x}".format(random.randint(0, 0xFFFFFF))
        colors.append(color)
    return colors

def generate_shape_frame(idx, anim_type, phase):
    frame = [[0 for _ in range(16)] for _ in range(16)]
    # anim_type decides the pattern
    if anim_type == 0:
        # Expanding circle
        r = (phase * 3) % 8
        for x in range(16):
            for y in range(16):
                dist = math.sqrt((x-7.5)**2 + (y-7.5)**2)
                if abs(dist - r) < 1.5:
                    frame[y][x] = random.randint(1,3)
    elif anim_type == 1:
        # Scrolling sine wave
        for x in range(16):
            y = int(8 + 4 * math.sin((x + phase * 4) * 0.5))
            if 0 <= y < 16:
                frame[y][x] = 1
                if y+1 < 16: frame[y+1][x] = 2
    elif anim_type == 2:
        # Bouncing ball
        y = int(14 - abs(math.sin(phase * math.pi / 4) * 10))
        x = (phase * 2) % 16
        if 0 <= y < 16 and 0 <= x < 16:
            frame[y][x] = 1
            if y+1 < 16: frame[y+1][x] = 2
            if x+1 < 16: frame[y][x+1] = 2
            if x+1 < 16 and y+1 < 16: frame[y+1][x+1] = 3
    elif anim_type == 3:
        # Rain
        for i in range(5):
            x = (i * 3 + idx) % 16
            y = (phase * 3 + i * 2) % 16
            frame[y][x] = 2
            if y-1 >= 0: frame[y-1][x] = 1
    elif anim_type == 4:
        # Rotating cross
        angle = phase * math.pi / 4
        cx, cy = 7.5, 7.5
        for length in range(-6, 7):
            x1 = int(cx + math.cos(angle) * length)
            y1 = int(cy + math.sin(angle) * length)
            if 0 <= x1 < 16 and 0 <= y1 < 16:
                frame[y1][x1] = 1
            x2 = int(cx - math.sin(angle) * length)
            y2 = int(cy + math.cos(angle) * length)
            if 0 <= x2 < 16 and 0 <= y2 < 16:
                frame[y2][x2] = 2
    elif anim_type == 5:
        # Pulsing diamond
        r = (phase * 2) % 8
        for x in range(16):
            for y in range(16):
                dist = abs(x-7.5) + abs(y-7.5)
                if abs(dist - r) < 1.5:
                    frame[y][x] = (phase % 3) + 1
    elif anim_type == 6:
        # Random stars
        random.seed(phase * 100 + idx)
        for _ in range(10):
            x = random.randint(0, 15)
            y = random.randint(0, 15)
            frame[y][x] = random.randint(1, 3)
    elif anim_type == 7:
        # Checkerboard shift
        offset = phase % 2
        for x in range(16):
            for y in range(16):
                if (x + y + offset) % 2 == 0:
                    frame[y][x] = 1
                else:
                    frame[y][x] = 2
    elif anim_type == 8:
        # Spiral
        cx, cy = 7.5, 7.5
        for r in range(1, 8):
            angle = r * 0.5 + phase * 0.5
            x = int(cx + math.cos(angle) * r)
            y = int(cy + math.sin(angle) * r)
            if 0 <= x < 16 and 0 <= y < 16:
                frame[y][x] = 3
    elif anim_type == 9:
        # Horizontal bars
        y = (phase * 2) % 16
        for x in range(16):
            frame[y][x] = 1
            if y+2 < 16: frame[y+2][x] = 2
            if y+4 < 16: frame[y+4][x] = 3
    return frame

def format_frame(frame):
    return "\\n".join("".join(str(c) for c in row) for row in frame)

out = open("lib/models/generated_sprites.dart", "w")
out.write("import 'sprites.dart';\n\n")
out.write("final Map<String, SpriteDef> generatedSprites = {\n")

for i in range(100):
    anim_type = i % 10
    colors = generate_palette()
    out.write(f"  'gen_{i}': SpriteDef(\n")
    out.write(f"    id: 'gen_{i}',\n")
    out.write(f"    name: 'Auto Gen {i}',\n")
    out.write(f"    palette: {colors!r},\n")
    out.write("    fps: const {'idle': 4, 'active': 8, 'tap': 12},\n")
    out.write("    frames: {\n")
    
    # Idle frames
    out.write("      'idle': buildFrames([\n")
    for phase in range(4):
        f = generate_shape_frame(i, anim_type, phase)
        out.write("'''\n" + format_frame(f) + "\n'''" + ("," if phase < 3 else "") + "\n")
    out.write("      ]),\n")
    
    # Active frames
    out.write("      'active': buildFrames([\n")
    for phase in range(8):
        f = generate_shape_frame(i, anim_type, phase)
        out.write("'''\n" + format_frame(f) + "\n'''" + ("," if phase < 7 else "") + "\n")
    out.write("      ]),\n")
    
    # Tap frames
    out.write("      'tap': buildFrames([\n")
    for phase in range(2):
        temp_phase = phase * 2 # faster tap
        f = generate_shape_frame(i, anim_type, temp_phase)
        out.write("'''\n" + format_frame(f) + "\n'''" + ("," if phase < 1 else "") + "\n")
    out.write("      ])\n")
    
    out.write("    }\n")
    out.write("  ),\n")

out.write("};\n")
out.close()
