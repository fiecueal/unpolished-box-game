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

def calc_timer args
  args.state.timer_start_tick ||= 0
  args.state.timer = {
    x: 0,
    y: 0,
    w: 1280 * args.easing.ease(args.state.timer_start_tick, args.state.tick_count, 1200, :quad, :flip),
    h: 720,
    path: :pixel,
    a: 100,
  }
end

def draw_backgrounds args
  args.state.background.source_x += args.state.background.dx
  args.state.background.source_y += args.state.background.dy
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

def spawn_platforms args
  args.state.platforms = [
  ]
end

def calc_player_running args
  return args.state.player.action = :falling unless args.state.player.platform

  # if player runs off the platform, start falling
  if args.state.player.right < args.state.player.platform.left ||
    args.state.player.left > args.state.player.platform.right
    args.state.player.platform = nil
    args.state.player.action = :falling
    return
  end

  if    args.inputs.keyboard.j then dir = -1
  elsif args.inputs.keyboard.l then dir = 1
  else                              dir = args.inputs.left_right
  end

  args.state.player.dx += dir * args.state.player.speed - args.state.player.dx * args.state.player.friction

  if args.inputs.up || args.inputs.keyboard.i
    args.state.player.jumped_at = args.state.tick_count
    args.state.player.dy = 20 * args.state.player.jump
    args.state.player.action = :jumping
    platform = nil
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

  if args.state.player.bottom <= args.state.platforms[0].top
    args.state.player.y = args.state.platforms[0].top
    args.state.player.dy = 0
    args.state.player.action = :running
    args.state.player.platform = args.state.platforms[0]
  end
end

def check_collisions args
  collisions = args.geometry.find_all_intersect_rect args.state.player, args.state.platforms
  return if collisions.empty?

  x_dir = args.state.player.dx.positive? ? :right : :left
  y_dir = args.state.player.dy.positive? ? :top : :bottom

  collisions.each do |platform|
    if args.state.player.dx.positive?

    else
    end
    if args.state.player.dy.positive?
    else
    end
  end
end

def calc_player_position args
  case args.state.player.action
  when :running then calc_player_running args
  when :jumping then calc_player_jumping args
  when :falling then calc_player_falling args
  end

  args.state.player.source_x = args.state.player.x += args.state.player.dx
  args.state.player.source_y = args.state.player.y += args.state.player.dy

  check_collisions args
end

def init args
  args.state.background ||= new_block 0, 0, 1280, 720,
                                      {
                                        path: "sprites/texture.png",
                                        dx: 0.4,
                                        dy: 0.4,
                                      }
  args.state.player ||= new_block 100, 360 - 50, 50, 50,
                                  {
                                    b: 200,
                                    dx: 0,
                                    dy: 0,
                                    speed: 1,
                                    jump: 1,
                                    friction: 0.1,
                                    action: :running
                                  }

  args.state.level ||= 0
  # first 4 platforms are always the bounds of the screen in order:
  # bottom, top, left, right
  args.state.platforms ||= [
    new_block(0, 0, 1280, 25),
    new_block(0, 720 - 25, 1280, 25),
    new_block(0, 0, 25, 720),
    new_block(1280 - 25, 0, 25, 720),
  ]

  args.state.plat_borders ||= args.state.platforms.map do |platform|
    {
      x: platform.x - 1,
      y: platform.y - 1,
      w: platform.w + 2,
      h: platform.h + 2,
      primitive_marker: :border,
    }
  end
end

def tick args
  init args
  calc_timer args
  draw_backgrounds args
  calc_player_position args

  args.outputs.primitives << [
    # args.state.background,
    args.state.plat_borders,
    args.state.platforms,
    args.state.player
  ]

  #===========================================================================#

  args.state.platforms << new_block(args.inputs.mouse.x, args.inputs.mouse.y, 200, 200) if args.inputs.mouse.click

  args.gtk.reset if args.inputs.keyboard.r
end
