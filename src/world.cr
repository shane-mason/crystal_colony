require "json"

class Tile
  include JSON::Serializable
  property height : Int32
  property target : Bool
  property colony : Bool
  @[JSON::Field(ignore: true)]
  property neighbors : Array(Tile)
  @[JSON::Field(ignore: true)]
  property costs : Array(Float64)
  property x : Int32
  property y : Int32
  property pheromone : Float64

  def initialize()
    @height = 0
    @target = false
    @colony = false
    # order: ne n nw e w se s sw
    @costs = Array(Float64).new(8, 0.0)
    @neighbors = Array(Tile).new(8)
    @x = 0
    @y = 0
    @pheromone = 0.0
  end

end

class NeighborhoodStats
  property count
  property average_height
  property cumulative_height

  def initialize()
    @count = 0
    @average_height = 0
    @cumulative_height = 0
  end

end

class World
  property x_size
  property y_size
  property max_height
  property low_mark
  property high_mark
  property colony_boundary
  property target_boundary
  property point_buffer
  property colony_spawn

  def initialize(size_x : Int32, size_y : Int32)
    @x_size = size_x
    @y_size = size_y
    @board = Array(Array(Tile)).new(@x_size) { Array(Tile).new(@y_size, Tile.new) }
    @max_height = 255
    @low_mark = 200
    @high_mark = 200
    @colony_boundary = 20
    @target_boundary = 20
    @point_buffer = 4
    @colony_spawn = {0,0}
    generate_topology()
    #smooth_topology()

  end

  def reset()
    puts "resetting"
    @board = Array(Array(Tile)).new(@x_size) { Array(Tile).new(@y_size, Tile.new) }
    generate_topology()
  end

  def get_spawn_tile
    return @board[@colony_spawn[0]][@colony_spawn[1]]
  end

  def calc_costs
    spinner = [{-1,-1},{0,-1},{1,-1},{-1,0}, {1,0}, {1,1}, {0,1}, {-1,1}]
    x = 1
    while x < @x_size-1
      y = 1
      while y < @y_size-1
        count = 0
        spinner.each do |c|
          height_diff =  @board[x+c[0]][y+c[1]].height - @board[x][y].height
          @board[x][y].costs[count] = height_diff.to_f
          @board[x][y].neighbors.push(@board[x+c[0]][y+c[1]])
          count+=1
        end
        y+=1
      end
      x+=1
    end
  end

  def merge_low
    x = 0
    while x < @x_size
      y = 0
      while y < @y_size
        if @board[x][y].height < @low_mark && @board[x][y].height > 10
          @board[x][y].height = (@board[x][y].height*0.8).to_i
        end
        y+=1
      end
      x+=1
    end
  end

  def get_neihborhood_stats(x, y)
    neighborhood = NeighborhoodStats.new

    if x > 0
      neighborhood.count += 1
      neighborhood.cumulative_height += @board[x-1][y].height
      if y>0
        neighborhood.count += 1
        neighborhood.cumulative_height += @board[x-1][y-1].height
      end
      if y < @y_size-1
        neighborhood.count += 1
        neighborhood.cumulative_height += @board[x-1][y+1].height
      end
    end
    if x < @x_size-1
      neighborhood.count += 1
      neighborhood.cumulative_height += @board[x+1][y].height
      if y > 0
        neighborhood.count += 1
        neighborhood.cumulative_height += @board[x+1][y-1].height
      end
      if y < @y_size-1
        neighborhood.count += 1
        neighborhood.cumulative_height += @board[x+1][y+1].height
      end

    end
    if y > 0
      neighborhood.count += 1
      neighborhood.cumulative_height += @board[x][y-1].height
    end
    if y < @y_size-1
      neighborhood.count += 1
      neighborhood.cumulative_height += @board[x][y+1].height
    end

    neighborhood.average_height = (neighborhood.cumulative_height/neighborhood.count).to_i
    return neighborhood
  end

  def declutter_high()
    x = 0
    while x < @x_size
      y = 0
      while y < y_size
        if @board[x][y].height > @high_mark
          neighborhood = get_neihborhood_stats(x,y)

          if neighborhood.average_height < @low_mark * 0.4
            @board[x][y].height = neighborhood.average_height
          end
        end
        y+=1
      end
      x+=1
    end
  end

  def generate_topology()
    rnd = Random.new
    x = 0
    while x < @x_size
      y = 0
      while y < @y_size
        tile = Tile.new
        tile.height = rnd.rand(@max_height)
        tile.x = x
        tile.y = y
        @board[x][y] = tile
        y+=1
      end
      x+=1
    end
  end

  def smooth_topology()
    rnd = Random.new
    x = 0
    while x < @x_size
      y = 0
      while y < @y_size
        neighborhood = get_neihborhood_stats(x,y)
        average = neighborhood.average_height
        #get diff from average
        diff = average - @board[x][y].height
        change = 0.0
        if diff > 10
          change = diff
        end
        @board[x][y].height = @board[x][y].height  + change.to_i
        y+=1
      end
      x+=1
    end
    #@board = new_board
  end

  def pick_points
    pick_target_points
    pick_colony_points
  end

  def pick_target_points

    @board.each do |row|
      row.each do |cell|
        cell.target = false
      end
    end

    rnd = Random.new
    target_point_found = false

    while !target_point_found

      test_x = @point_buffer + rnd.rand(@x_size-@point_buffer*2)
      test_y = @point_buffer + rnd.rand(@target_boundary-@point_buffer*2)
      avg = get_neihborhood_stats(test_x, test_y)
      if avg.average_height < @low_mark/2

        start_y = test_y - rnd.rand(@point_buffer-1) - 1
        end_y = test_y + rnd.rand(@point_buffer-1) + 1
        y = start_y

        while y < end_y

          start_x = test_x - rnd.rand(@point_buffer-1) - 1
          end_x = test_x + rnd.rand(@point_buffer-1) + 1
          x = start_x
          while x < end_x
            @board[x.to_i][y.to_i].target = true
            x+=1
          end
          y+=1
        end
        target_point_found = true
      end
    end

  end

  def pick_colony_points

    @board.each do |row|
      row.each do |cell|
        cell.colony = false
      end
    end

    rnd = Random.new
    target_point_found = false

    while !target_point_found

      test_x = @point_buffer + rnd.rand(@x_size-@point_buffer*2)
      test_y = @y_size - (@point_buffer + rnd.rand(@target_boundary-@point_buffer*2))
      avg = get_neihborhood_stats(test_x, test_y)

      if avg.average_height < @low_mark/2
        @colony_spawn = {test_x,test_y}
        start_y = test_y - @point_buffer/2
        end_y = test_y + @point_buffer/2 - 1
        y = start_y

        while y < end_y
          start_x = test_x - @point_buffer/2
          end_x = test_x + @point_buffer/2 -1
          x = start_x
          while x < end_x
            @board[x.to_i][y.to_i].colony = true
            x+=1
          end
          y+=1
        end
        target_point_found = true
      end
    end

  end

  def tick_sim
    @board.each do |row|
      row.each do |cell|
        if cell.pheromone > 0
          cell.pheromone -= 0.5
        end
      end
    end
  end

  def get_world_view
    return @board.to_json
  end

end
