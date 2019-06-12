# Type Structs
defmodule Flight do
  defstruct origin: nil, dest: nil, dist: 0
end

defmodule Plane do
  defstruct id: "", location: nil, miles: 0
end

defmodule EventHandler do
  def listen(state_changes) do
    receive do
      {:add, event} -> listen add_change(state_changes, event)
      {:replay, id} -> replay_changes(state_changes, id) |> IO.inspect()
      {:view, id}   -> view_changes(state_changes, id) |> IO.inspect()
    end
    listen state_changes
  end
  def add_change(state, {id, flight}) do
    IO.puts "ADD CHANGE"
    Map.update(state, id, [flight], &[flight|&1])
  end
  def replay_changes(state_changes, id) do
    IO.puts "REPLAY CHANGES"
    Map.fetch!(state_changes, id)
    |> List.foldr(%Plane{id: id, location: nil, miles: 0},
      &%Plane{id: &2.id, location: &1.dest, miles: &2.miles + &1.dist})
  end
  def view_changes(state_changes, id) do
    IO.puts "VIEW CHANGES"
    Map.fetch!(state_changes, id)
    |> Enum.reverse()
  end
end

#--------------------------------------------------------------------------------
# Air Traffic Control
#--------------------------------------------------------------------------------
defmodule AirControl do
  @geo_locations %{
    "New York City" => {40.6943, -73.9249},
    "Chicago" => {41.8373, -87.6861},
    "Washington D.C." => {38.9047, -77.0163},
    "Baltimore" => {39.3051, -76.6144},
    "Philadelphia" => {32.7761, -89.1221},
    "Boston" => {42.3188, -71.0846},
    "Pittsburgh" => {40.4396, -79.9763},
  }

  @doc "calculate approx distance between two long/lat points in miles"
  def calc_miles({x1, y1}, {x2, y2}) do
    :math.sqrt(:math.pow(x2 - x1, 2) + :math.pow((y2 - y1), 2)) * 55
  end

  @doc "provided a plane and a destination, apply flight event"
  def fly(%Plane{id: id, location: loc, miles: m}, dest_name, eh_pid) do
    origin = Map.fetch!(@geo_locations, loc)
    dest   = Map.fetch!(@geo_locations, dest_name)
    distance = calc_distance(origin, dest)
    # building our event to
    flight = %Flight{
      origin: loc,
      dest: dest_name,
      dist: distance,
    }
    plane = %Plane{id: id, location: dest_name, miles: m + flight.dist}
    send eh_pid, {:add, {id, flight}}
    plane
  end

  def main do
    # spawn event handler
    eh_pid = spawn(EventHandler, :listen, [%{}])
    IO.inspect eh_pid

    # example plane traversal
    plane = %Plane{id: "abc123", location: "New York City"}
    |> fly("Chicago", eh_pid)
    |> fly("Baltimore", eh_pid)
    |> fly("Boston", eh_pid)
    |> fly("Philadelphia", eh_pid)
    |> IO.inspect()

    # view
    send eh_pid, {:view, plane.id}

    # replay
    send eh_pid, {:replay, plane.id}
  end
end
