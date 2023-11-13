def boot args = $args
  # inputs.left_right only check wasd & arrows keys so ijl are checked separately
  @player_actions = { grounded: -> args {
    if    args.inputs.keyboard.j then dir = -1
    elsif args.inputs.keyboard.l then dir = 1
    else                              dir = args.inputs.left_right
    end

    @player.dx               += dir * @stat_mods.accel - @player.dx * @stat_mods.friction
    @player.angle             = -@player.dx
    @player.flip_horizontally = @player.dx < 0

    if args.inputs.up || args.inputs.keyboard.i
      @jump_tick       = args.state.tick_count
      @player.dy       = 10 * @stat_mods.jump
      @player.action   = @player_actions.jumping
      @player.platform = nil
    end
  }, jumping: -> args {
    @player.angle = Math::atan(@player.dy / @player.dx) * 180 / Math::PI

    unless (args.inputs.up || args.inputs.keyboard.i) && @jump_tick.elapsed_time <= 10
      @player.dy    /= 2 # looks "smoother" when dy is halved for some reason
      @player.action = @player_actions.freefall
    end
  }, freefall: -> args {
    @player.dy   -= 1
    @player.angle = Math::atan(@player.dy / @player.dx) * 180 / Math::PI

    # TODO: remove code below from :freefall and handle elsewhere
    if @player.bottom <= 0
      @player.y               = 0
      @player.dy              = 0
      @player.flip_vertically = false
      @player.action          = @player_actions.grounded
    end
  } }

  @level_start_tick = 0

  # coincidentally, max speed ends up being roughly equal to `accel / friction`
  # bad things happen with negative friction
  @stat_mods = { accel: 1, jump: 1,  friction: 0.1 }

  @player = {
    x: 640, y: 640,
    dx: 0, dy: 0,
    w: 64, h: 64,
    path: "sprites/fish.png",
    angle: 0,
    action: @player_actions.freefall,
    platform: nil,
  }

  @blocks = []
  @blocks << new_block(500, 35)
  @blocks << new_block(60, 335)

  puts 'arrows: ←↑→'
end

def new_block x, y
  { x: x, y: y, w: 70, h: 70,
    path: "sprites/block_3.png",
    anchor_x: 0.5, anchor_y: 0.5,
    hp: 3 }
end

def drop_player
  return unless @player.platform

  if @player.left > @player.platform.right || @player.right < @player.platform.left
    @player.platform = nil
    @player.action = @player_actions.freefall
  elsif @player.platform.hp && @player.platform.hp.zero?
    @player.platform = nil
    @player.action = @player_actions.freefall
  end
end

# only handles collision when player is in motion
def reflect_player hit_block
  return unless hit_block

  if hit_block.hp
    @blocks.delete hit_block if (hit_block.hp -= 1).zero?
    hit_block.path = "sprites/block_#{hit_block.hp}.png"
  end

  # calc'd based on hit_block perspective
  # difference is negative if no collision
  top_cl    = hit_block.top   - @player.bottom
  right_cl  = hit_block.right - @player.left
  bottom_cl = @player.top     - hit_block.bottom
  left_cl   = @player.right   - hit_block.left

  if top_cl < bottom_cl && top_cl < left_cl && top_cl < right_cl
    @player.y        = hit_block.top
    @player.dy       = 0
    @player.action   = @player_actions.grounded
    @player.platform = hit_block
  elsif bottom_cl < left_cl && bottom_cl < right_cl
    @player.y  = hit_block.bottom - @player.h
    @player.dy = -@player.dy
  elsif right_cl < left_cl
    @player.x  = hit_block.right - @player.dx
    @player.dx = -@player.dx
    @player.flip_horizontally = false
  else
    @player.x  = hit_block.left - @player.w - @player.dx
    @player.dx = -@player.dx
    @player.flip_horizontally = true
  end
end

def tick args
  timer         = args.easing.ease(@level_start_tick, args.state.tick_count, 1200, :identity)
  timer_flipped = 1 - timer
  @player.x    += @player.dx
  @player.y    += @player.dy

  reflect_player args.geometry.find_intersect_rect(@player, @blocks)
  drop_player

  @player.action.call args

  args.outputs.primitives << [
    @blocks,
    @player,
    @player.to_border,
    { x: 0, y: 700, w: timer_flipped * 1280, h: 20, r: 100 }.solid!,
  ]
  args.outputs.debug << [
    args.gtk.framerate_diagnostics_primitives,
    # args.layout.debug_primitives,
    { x: 0, y: 20, text: "#{@player.dx}, #{@player.dy}" },
  ]

  args.gtk.reset if args.inputs.keyboard.r

  if args.inputs.mouse.click
    @blocks << new_block(args.inputs.mouse.x, args.inputs.mouse.y)
  end

  # if args.inputs.keyboard.key_down.f
  #   args.gtk.console.show
  #   args.gtk.benchmark iterations: 1000,
  # end
end

def reset
  boot
end

$gtk.reset
