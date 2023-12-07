def new_block x, y, w, h, props = {}
  {
    x: x,
    y: y,
    w: w,
    h: h,
    path: :background,
    source_x: x,
    source_y: y,
    source_w: w,
    source_h: h,
  } << props
end

def draw_background args
  args.state.background.source_x += args.state.background.dx
  args.state.background.source_y += args.state.background.dy
  # 2048x2048 is the unnecessarily large size of the sprites used by everything
  args.state.background.dx = -args.state.background.dx if args.state.background.source_x <= 0 ||
                                                          args.state.background.source_x + 1280 >= 2048
  args.state.background.dy = -args.state.background.dy if args.state.background.source_y <= 0 ||
                                                          args.state.background.source_y + 720 >= 2048
  args.outputs[:background].transient!
  args.outputs[:background].w = 1280
  args.outputs[:background].h = 720
  args.outputs[:background].primitives << [
    args.state.background,
    args.state.timer,
  ]
end

def calc_player_running args
  return args.state.player.action = :falling unless args.state.player.platform

  if    args.inputs.keyboard.j then dir = -1
  elsif args.inputs.keyboard.l then dir = 1
  else                              dir = args.inputs.left_right
  end

  args.state.player.moved = true unless dir.zero?

  args.state.player.dx += dir * args.state.player.speed - args.state.player.dx * args.state.player.friction

  # if player runs off the platform, start falling
  if args.state.player.right < args.state.player.platform.left ||
    args.state.player.left > args.state.player.platform.right
    args.state.player.platform = nil
    args.state.player.action = :falling
  end

  if args.inputs.up || args.inputs.keyboard.i
    args.state.player.jumped_at = args.state.tick_count
    args.state.player.dy = 20 * args.state.player.jump
    args.state.player.action = :jumping
    args.state.player.platform = nil
    args.state.player.moved = true
  end
end

def calc_player_jumping args
  unless (args.inputs.up || args.inputs.keyboard.i) && args.state.player.jumped_at.elapsed_time <= 10
    args.state.player.dy    /= 2 # looks "smoother" when dy is halved for some reason
    args.state.player.action = :falling
  end
end

def calc_player_falling args
  args.state.player.dy -= 1
end

def find_collision args, direction
  platform = args.geometry.find_intersect_rect args.state.player, args.state.platforms
  return unless platform
  return if platform.is_untouchable

  if platform.is_respawner
    args.state.player.dx = 0
    args.state.player.dy = 0
    args.state.player.x = args.state.respawn.x
    args.state.player.y = args.state.respawn.y
    return
  end

  if direction == :x
    if args.state.player.dx.positive? then args.state.player.x = platform.left - args.state.player.w
    else                                   args.state.player.x = platform.right
    end
    args.state.player.dx = -args.state.player.dx
  elsif direction == :y then
    if args.state.player.dy.positive?
      args.state.player.y = platform.bottom - args.state.player.h
      args.state.player.dy = -args.state.player.dy
    else # land on the surface if collided with top of platform
      args.state.player.y = platform.top
      args.state.player.dy = 0
      args.state.player.action = :running
      args.state.player.platform = platform
    end
  end
end

def calc_player_movement args
  case args.state.player.action
  when :running then calc_player_running args
  when :jumping then calc_player_jumping args
  when :falling then calc_player_falling args
  end

  args.state.player.source_x = args.state.player.x += args.state.player.dx
  find_collision args, :x
  args.state.player.source_y = args.state.player.y += args.state.player.dy
  find_collision args, :y
end

def calc_timer args, progress
  args.state.timer = {
    x: 0,
    y: 0,
    w: 1280 * progress,
    h: 720,
    path: :pixel,
    a: 100,
  }
end

def calc_level_progress args
  args.state.timer_start_tick = args.state.tick_count unless args.state.player.moved
  progress = args.easing.ease(args.state.timer_start_tick,
                              args.state.tick_count,
                              20.seconds,
                              :quad, :flip)
  if progress.zero?
    args.state.lives -= 1
    if args.state.lives.zero?
      args.state.lives = 3
      args.state.level -= 1
      args.state.level = 1 if args.state.level.zero?
    end
    start_level args
    return
  end

  calc_timer args, progress

  if args.state.player.intersect_rect? args.state.goal
    args.state.level += 1
    args.state.lives += 3
    start_level args
  end
end

def start_level args
  args.state.player << {
    dx: 0,
    dy: 0,
    speed: 1,
    jump: 1,
    friction: 0.1,
    action: :falling,
    moved: false,
    platform: nil
  }
  # first 4 platforms are always the bounds of the screen in order:
  # bottom, top, left, right
  args.state.platforms = [
    new_block(0, 0, 1280, 25),
    new_block(0, 720 - 25, 1280, 25),
    new_block(0, 0, 25, 720),
    new_block(1280 - 25, 0, 25, 720),
  ]

  case args.state.level
  when 1
    args.state.player.x = 180 - 50
    args.state.player.y = 360 - 50
    args.state.goal.x = 1120 - 25
    args.state.goal.y = 100
    args.state.platforms += [
      new_block(320 - 25, 25, 50, 250),
      new_block(640 - 25, 25, 50, 250),
      new_block(960 - 25, 25, 50, 250),
    ]
  when 2
    args.state.player.x = 75
    args.state.player.y = 360 - 50
    args.state.goal.x = 1280 - 75
    args.state.goal.y = 45
    args.state.respawn = new_block 75, 25, 50, 50, { is_untouchable: true, g: 200, b: 200 }
    args.state.platforms += [
      new_block(200 - 25,  25, 50, 250),
      new_block(640 - 25,  25, 50, 250),
      new_block(1080 - 25, 25, 50, 250),
      args.state.respawn,
      new_block(200 + 25,  25, 440 - 50, 20, { is_respawner: true, g: 200, b: 200 }),
      new_block(640 + 25,  25, 440 - 50, 20, { is_respawner: true, g: 200, b: 200 }),
      new_block(1080 + 25, 25, 150,      20, { is_respawner: true, g: 200, b: 200 }),
    ]
  when 3
  when 4
  when 5
  else
    args.state.goal.y = 640
    args.outputs.static_labels << {
      x: args.grid.w / 2,
      y: args.grid.h / 2,
      text: "congrats... i'm out of level ideas (and time :P)",
      alignment_enum: 1,
      vertical_alignment_enum: 1,
    }
  end

  args.state.plat_borders = args.state.platforms.map do |platform|
    {
      x: platform.x - 1,
      y: platform.y - 1,
      w: platform.w + 2,
      h: platform.h + 2,
      primitive_marker: :border,
    }
  end
  args.state.plat_borders << {
    x: args.state.goal.x - 1,
    y: args.state.goal.y - 1,
    w: args.state.goal.w + 2,
    h: args.state.goal.h + 2,
    primitive_marker: :border,
  }
end

def init args
  args.state.background ||= new_block 0, 0, 1280, 720,
                                      {
                                        path: "sprites/texture.png",
                                        dx: 0.4,
                                        dy: 0.4,
                                      }
  # player max speed ends up being speed * friction
  args.state.player ||= new_block 50, 50, 50, 50,
                                  {
                                    b: 200,
                                    dx: 0,
                                    dy: 0,
                                    speed: 1,
                                    jump: 1,
                                    friction: 0.1,
                                    action: :falling,
                                    moved: false
                                  }
  args.state.goal ||= new_block 50, 50, 50, 50,
                                {
                                  r: 200,
                                  dx: 5,
                                  dy: 5,
                                }
  args.state.level ||= 0
  args.state.lives ||= 3
end

def tick args
  init args
  calc_level_progress args
  calc_player_movement args
  draw_background args

  args.outputs.primitives << [
    args.state.plat_borders,
    args.state.platforms,
    args.state.goal,
    args.state.player,
  ]

  args.state.start_level args if args.inputs.keyboard.key_down.r
  debug args
end

def debug args
  if args.inputs.mouse.click
    if args.state.first_point
      args.state.platforms << new_block(args.state.first_point[0],
                                        args.state.first_point[1],
                                        args.inputs.mouse.x - args.state.first_point[0],
                                        args.inputs.mouse.y - args.state.first_point[1])
      args.state.first_point = nil
    else
      args.state.first_point = [ args.inputs.mouse.x, args.inputs.mouse.y ]
    end
  end

  args.outputs.primitives << args.gtk.framerate_diagnostics_primitives
  args.outputs.borders << {
    x: args.state.first_point[0],
    y: args.state.first_point[1],
    w: args.inputs.mouse.x - args.state.first_point[0],
    h: args.inputs.mouse.y - args.state.first_point[1],
  } if args.state.first_point

  if args.inputs.keyboard.key_down.n
    args.state.level += 1
    start_level args
  end
  args.gtk.reset if args.inputs.keyboard.b
end
