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
      @jump_tick     = args.state.tick_count
      @player.dy     = 10 * @stat_mods.jump
      @player.action = @player_actions.jumping
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
  @stat_mods = { accel: 2, jump: 2,  friction: 0.2 }

  @player = {
    x: 50, y: 500,
    dx: 0, dy: 0,
    w: 64, h: 64,
    path: "sprites/fish.png",
    angle: 0, anchor_x: 0.5, anchor_y: 0,
    action: @player_actions.freefall,
  }

  @blocks = []
  @blocks << stone(100, 70)
end

def stone x, y
  { x: x, y: y, w: 70, h: 70, path: "sprites/block_3.png", hp: 3 }
end

def reflect_player hit_block
  return unless hit_block
  @blocks.delete hit_block if (hit_block.hp -= 1).zero?

  hit_block.path = "sprites/block_#{hit_block.hp}.png"

  if @player.dx.to_i.zero?
    if @player.dy > 0 then @player.y = hit_block.bottom - @player.h
    else                   @player.y = hit_block.top
    end

    @player.dy = -@player.dy
  elsif @player.dy.to_i.zero?
    if @player.dx > 0 then @player.x = hit_block.left - @player.w
    else                   @player.x = hit_block.right
    end

    @player.dx = -player.dx
  end
end

def tick args
  @timer         = args.easing.ease(@level_start_tick, args.state.tick_count, 1200, :identity)
  @timer_flipped = 1 - @timer

  @player.action.call args
  @player.x += @player.dx
  @player.y += @player.dy

  reflect_player args.geometry.find_intersect_rect(@player, @blocks)

  args.outputs.primitives << [
    @blocks,
    @player,
    { x: 0, y: 700, w: @timer_flipped * 1280, h: 20, r: 100 }.solid!,
  ]
  args.outputs.debug << [
    args.gtk.framerate_diagnostics_primitives,
    # args.layout.debug_primitives,
    { x: 0, y: 20, text: "#{@player.dx}, #{@player.dy}" },
  ]

  args.gtk.reset if args.inputs.keyboard.r

  # if args.inputs.keyboard.key_down.f
  #   args.gtk.console.show
  #   args.gtk.benchmark iterations: 1000,
  # end
end

def reset
  boot
end

$gtk.reset
