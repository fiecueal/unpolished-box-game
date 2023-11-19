def boot args = $args
  # inputs.left_right only check wasd & arrows keys so ijl are checked separately
  @player_actions = { grounded: -> args {
    # TODO: fix... something? this guard clause should not be needed;
    # player should never be set to grounded without a platform
    return @player.action = @player_actions.freefall unless @player.platform
    if    args.inputs.keyboard.j then dir = -1
    elsif args.inputs.keyboard.l then dir = 1
    else                              dir = args.inputs.left_right
    end

    @player.dx += dir * @stat_mods.accel - @player.dx * @stat_mods.friction

    # if player steps off current platform or it breaks,
    # check if a block exists just below the player and switch platforms
    # else start falling
    if @player.left > @player.platform.right ||
       @player.right < @player.platform.left ||
       @player.platform.hp && @player.platform.hp.zero?
      @player.action   = @player_actions.freefall
      @player.platform = nil
    end

    if args.inputs.up || args.inputs.keyboard.i
      @jump_tick       = args.state.tick_count
      @player.dy       = 10 * @stat_mods.jump
      @player.action   = @player_actions.jumping
      @player.platform = nil
    end
  }, jumping: -> args {
    # @player.angle = Math::atan(@player.dy / @player.dx) * 180 / Math::PI

    unless (args.inputs.up || args.inputs.keyboard.i) && @jump_tick.elapsed_time <= 10
      @player.dy    /= 2 # looks "smoother" when dy is halved for some reason
      @player.action = @player_actions.freefall
    end
  }, freefall: -> args {
    @player.dy   -= 1
    # @player.angle = Math::atan(@player.dy / @player.dx) * 180 / Math::PI

    # TODO: remove code below from :freefall and handle elsewhere
    if @player.bottom <= 0
      @player.y        = 0
      @player.dy       = 0
      @player.action   = @player_actions.grounded
      @player.platform = { x: @player.x, y: @player.y, w: @player.w, h: 0 }
    end
  } }

  @level_start_tick = 0

  # coincidentally, max speed ends up being roughly equal to `accel / friction`
  # bad things happen with negative friction
  @stat_mods = { accel: 1, jump: 1,  friction: 0.1 }

  @player = {
    x: 640,
    y: 640,
    dx: 0,
    dy: 0,
    w: 40,
    h: 40,
    path: "sprites/urchin.png",
    r: 0,
    g: 0,
    b: 0,
    angle: 0,
    action: @player_actions.freefall,
    platform: nil,
  }

  @blocks = 20.map do |x|
    if x.zero? || x == 19
      4.map { |y| new_block(64 * x, 64 * y) }
    else
      new_block(64 * x, x)
    end
  end.flatten!

  puts 'arrows: ←↑→'
  puts @blocks
end

def new_block x, y, hp = nil
  { x: x, y: y, w: 64, h: 64, path: "sprites/block_#{hp}.png", hp: hp }
end

def collide dir, hit_block
  case dir
  when :top
    # player lands on top of hit_block instead of bouncing
    @player.y        = hit_block.top
    @player.dy       = 0
    @player.action   = @player_actions.grounded
    @player.platform = hit_block
    puts "\nhit top"
  when :right
    @player.x  = hit_block.right - @player.dx
    @player.dx = -@player.dx
    puts "\nhit right"
  when :bottom
    @player.y  = hit_block.bottom - @player.h
    @player.dy = -@player.dy
    puts "\nhit bottom"
  when :left
    @player.x  = hit_block.left - @player.w - @player.dx
    @player.dx = -@player.dx
    puts "\nhit left"
  end
end

# only handles collision when player is in motion
def find_collision args
  hit_blocks = args.geometry.find_all_intersect_rect(@player, @blocks)
  return if hit_blocks.empty?

  block = hit_blocks.first

  hit_blocks.each do |b|
    if b.hp
      @blocks.delete b if (b.hp -= 1).zero?
      b.path = "sprites/block_#{b.hp}.png"
    end
  end

  # calc'd based on hit_block perspective
  # always positive, hit direction is the smallest number
  top_cl    = block.top     - @player.bottom
  right_cl  = block.right   - @player.left
  bottom_cl = @player.top   - block.bottom
  left_cl   = @player.right - block.left

  # makes things smoother when platforms are only slightly different in height
  return collide :top, block if top_cl < 2 && @player.dy < 2

  if @player.dy.to_i.zero? # if only moving horizontally
    if    @player.dx.positive? then collide :left, block
    elsif @player.dx.negative? then collide :right, block
    end
    puts "\ntop:#{top_cl}\nbottom:#{bottom_cl}\nright:#{right_cl}\nleft:#{left_cl}"
    return
  elsif @player.dx.to_i.zero? # if only moving vertically
    if    @player.dy.positive? then collide :bottom, block
    elsif @player.dy.negative? then collide :top, block
    end
    return
  end

  if top_cl < bottom_cl && top_cl < left_cl && top_cl < right_cl
    collide :top, block
  elsif bottom_cl < top_cl && bottom_cl < left_cl && bottom_cl < right_cl
    collide :bottom, block
  elsif right_cl < left_cl && right_cl < top_cl && right_cl < bottom_cl
    collide :right, block
  else
    collide :left, block
  end
  puts "\ntop:#{top_cl}\nbottom:#{bottom_cl}\nright:#{right_cl}\nleft:#{left_cl}"

  find_collision args
end

def tick args
  timer         = args.easing.ease(@level_start_tick, args.state.tick_count, 1200, :identity)
  timer_flipped = 1 - timer

  @player.x     += @player.dx
  @player.y     += @player.dy
  @player.angle -= @player.dx

  @player.action.call args
  find_collision args

  args.outputs.primitives << [
    @blocks,
    @player,
    { x: 0, y: 700, w: timer_flipped * 1280, h: 20, r: 100 }.solid!,
  ]

  debug args
end

def debug args
  if args.inputs.keyboard.r
    args.gtk.reset
  end

  if args.inputs.mouse.click
    case args.inputs.mouse.button_bits
    when 1 # left click to spawn breakable block
      @blocks << new_block(args.inputs.mouse.x, args.inputs.mouse.y, 3)
    when 2 # middle click to delete all blocks containing pointer
      args.geometry.find_all_intersect_rect(args.inputs.mouse,@blocks).each do |block|
        @blocks.delete block
        block.hp = 0
      end
    when 4 # right click to spawn unbreakable block
      @blocks << new_block(args.inputs.mouse.x, args.inputs.mouse.y)
    end
    puts @blocks
  end

  args.outputs.debug << [
    args.gtk.framerate_diagnostics_primitives,
    # args.layout.debug_primitives,
    { x: 0, y: 20, text: "#{@player.dx}, #{@player.dy}" },
  ]
  # if args.inputs.keyboard.key_down.f
  #   args.gtk.console.show
  #   args.gtk.benchmark iterations: 1000,
  # end
end

def reset
  boot
end
