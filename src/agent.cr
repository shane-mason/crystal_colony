require "json"

FUZZ  = 0.1
HFUZZ = 0.05
BASE_PHERO_ATTRACTION = 0.95
DIR_COUNT = 8
FIFTYFIFTY = 0.5
MAX_PHEROMONE = 255
MAX_COST = 255

class Agent
  include JSON::Serializable
  property tile
  property x
  property y
  property loaded
  property id
  @[JSON::Field(ignore: true)]
  property x_boundary
  @[JSON::Field(ignore: true)]
  property y_boundary
  @[JSON::Field(ignore: true)]
  property elevation_threshhold
  @[JSON::Field(ignore: true)]
  property randomness
  @[JSON::Field(ignore: true)]
  property turn_weights
  @[JSON::Field(ignore: true)]
  property track : Array(Tile)
  @[JSON::Field(ignore: true)]
  property pheromones : Array(Tile)
  @[JSON::Field(ignore: true)]
  property tick_age
  @[JSON::Field(ignore: true)]
  property returned


  def initialize( @tile : Tile, @x_boundary : Int32, @y_boundary : Int32, @id : Int32 )
    @last_dir = 0
    @last_dir = Random.rand(DIR_COUNT)
    @x = tile.x
    @y = tile.y
    @elevation_threshhold = 1
    @randomness = HFUZZ
    #left, right direction weights
    @turn_weights = {HFUZZ, HFUZZ}
    @loaded = false
    @track = Array(Tile).new()
    @pheromones = Array(Tile).new()
    @pheromone_level = 0
    @pheromone_attraction = BASE_PHERO_ATTRACTION
    @pheromone_blocker = 0.0
    @pheromone_blocker_decay = FUZZ
    @tick_age = 0
    @returned = false

    fuzz_genetics
  end

  def fuzz_genetics

    #if Random.rand > 0.5
    #  @elevation_threshhold += Random.rand 1
    #else
    #  @elevation_threshhold -= Random.rand 1
    #end

    if Random.rand > FIFTYFIFTY
      left = @turn_weights[0] + Random.rand FUZZ
      right = 1 - left
      @turn_weights = {left, right}
    else
      left = @turn_weights[0] - Random.rand FUZZ
      right = 1 - left
      @turn_weights = {left, right}
    end

    if Random.rand > FIFTYFIFTY
      @randomness += Random.rand HFUZZ
    else
      @randomness -= Random.rand HFUZZ
    end

    if Random.rand > FIFTYFIFTY
      @pheromone_attraction += Random.rand HFUZZ
    else
      @pheromone_attraction -= Random.rand HFUZZ
    end

  end


  def tick
    @tick_age+=1
    if @pheromone_blocker > 0
      @pheromone_blocker-=@pheromone_blocker_decay
    end

    #are we loaded and on the way back to colony?
    if @loaded == true && @returned == false

      if @track.size > 0
        if @tile.pheromone < @pheromone_level
          @tile.pheromone = @pheromone_level
        end
        @pheromones.push(@tile)
        @pheromone_level -= 1

        #only move if elevation isn't too high (blocked path)
        if track[-1].height < @elevation_threshhold
          next_tile = @track.pop

          #test if we've been here before
          first_visited = @track.index(@tile)
          if first_visited && first_visited >= 0 && first_visited < @track.size - 1
            @track = @track.first(first_visited)
          end

          @x = next_tile.x
          @y = next_tile.y
          @tile = next_tile

          if @tile.colony
            #then we are back at the colony - avoid looping back out
            @returned = true
            @track.clear
          end

        end

      else
        @returned = true

      end
    else
      pick_next
    end
  end


  def pick_next

    #first - check for pheromone levels
    max_pheromone_dir = get_highest_pheromone
    if @pheromone_blocker <= 0 && max_pheromone_dir[0] > -1 && max_pheromone_dir[1] > @tile.pheromone
      #then we should go that way
      new_dir = max_pheromone_dir[0]

      if @tile.costs[new_dir] > @elevation_threshhold
        @pheromone_blocker = 1
        #then this means that this path isn't valid
        valid_path = false
        test_count = 0
        while valid_path==false && test_count < DIR_COUNT
          new_dir = shift_dir @last_dir
          if @tile.costs[new_dir] < @elevation_threshhold
            valid_path = true
          end
          test_count+=1
        end

      end
    else

      if @tile.costs[@last_dir] > @elevation_threshhold || randomness > Random.rand

        dirs = get_valid_dirs
        if dirs.size > 0
          new_dir = dirs.shuffle[0]
        else
          new_dir = get_min_cost_dir
        end

      else
        # assume same direction initially
        new_dir = @last_dir
      end
    end


    # is the new tile a border tile?
    if @tile.neighbors[new_dir].neighbors.size == 0
        new_dir = reverse_dir(@last_dir)
        #don't move until next tick
    else
      @tile = @tile.neighbors[new_dir]
      @track.push(@tile)
      if @tile.target == true
        @loaded = true
        @pheromone_level = MAX_PHEROMONE
      end
      @x = @tile.x
      @y = @tile.y
    end

    @last_dir = new_dir
  end

  def shift_dir(dir)
    new_dir = dir
    if @turn_weights[0] > Random.rand
      #then left turn
      new_dir -= 1
    else
      new_dir += 1
    end

    if new_dir < 0
      new_dir = DIR_COUNT + new_dir
    elsif new_dir >= DIR_COUNT
      new_dir = new_dir - DIR_COUNT
    end
    return new_dir
  end

  def reverse_dir(dir)
    reversed = dir + Random.rand((DIR_COUNT/2).to_i) + 2
    if reversed >= DIR_COUNT
      reversed = reversed - DIR_COUNT
    end
    return reversed
  end

  def get_min_cost_dir()
    i = 0
    min = -1
    min_val = MAX_COST
    while i < @tile.costs.size
      if @tile.costs[i] < min_val
        min = i
        min_val = @tile.costs[i]
      end
      i+=1
    end
    return min
  end

  def get_highest_pheromone()
    i = 0
    max_i = -1
    max_val = 0
    while i < DIR_COUNT
      if @tile.neighbors[i].pheromone > max_val
        max_i = i
        max_val = @tile.neighbors[i].pheromone
      end
      i+=1
    end
    return {max_i, max_val}
  end

  def get_valid_dirs()
    valid_paths = [] of Int32
    (0...@tile.costs.size).each do |i|
      if @tile.costs[i] < @elevation_threshhold
        valid_paths.push(i)
      end
    end
    return valid_paths
  end

end
