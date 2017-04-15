import "futlib/math"
import "futlib/colour"

import "step"

let shiftHoods (offset: i32) (hoods: [#w][#h]hood): [w][h]hood =
  let new_offset = if offset == 0 then -1 else 0
  in map (\x -> map (\y ->
                     let ul = worldIndex offset hoods (x*2+new_offset+0, y*2+new_offset+0)
                     let dl = worldIndex offset hoods (x*2+new_offset+0, y*2+new_offset+1)
                     let ur = worldIndex offset hoods (x*2+new_offset+1, y*2+new_offset+0)
                     let dr = worldIndex offset hoods (x*2+new_offset+1, y*2+new_offset+1)
                     in hoodFromQuadrants ul ur dl dr)
          (iota h)) (iota w)

  let divRoundingUp (x: i32) (y: i32): i32 =
    (x + y - 1) / y

type game_state [w][h] = {generation: i32,   -- generation
                          hoods: [w][h]hood, -- world data
                          width: i32,        -- world width
                          height: i32        -- world height
                          }

let new_game_with (ww:i32,wh:i32) (e: element): game_state [][] =
  let w = divRoundingUp ww 2
  let h = divRoundingUp wh 2
  in {generation = 0,
      hoods = replicate w (replicate h (hoodFromQuadrants e e e e)),
      width = ww, height = wh}

entry new_game (ww: i32) (wh: i32) = new_game_with (ww,wh) nothing
entry new_game_random (ww: i32) (wh: i32) = new_game_with (ww,wh) turnip

entry step ({generation=gen,hoods,width=ww,height=wh}: game_state [#w][#h]) =
  let hoods' = one_step (gen+1) (shiftHoods (gen%2) hoods)
  in {generation=gen+1, hoods=hoods', width=ww, height=wh}

open argb

let screen_point_to_world_point ((ul_x, ul_y): (f32,f32)) (s: f32)
                                ((sw,sh): (i32,i32)) ((ww,wh): (i32,i32))
                                ((x,y): (i32,i32)) =
  let x' = i32 ((ul_x + s * (f32 x / f32 sw)) * f32 ww)
  let y' = i32 ((ul_y + s * (f32 y / f32 sh)) * f32 wh)
  in (x', y')

let elemColour (x: element): i32 =
  if      x == steam_water
  then bright (light (light (light blue)))
  else if x == steam_condensed
  then bright (light (light (light blue)))
  else if x == oil
  then brown
  else if x == water
  then bright (bright (light blue))
  else if x == salt_water
  then bright (bright (light (light blue)))
  else if x == sand
  then dim yellow
  else if x == salt
  then gray 0.95f32
  else if x == stone
  then gray 0.7f32
  else if x == torch
  then bright orange
  else if x == plant
  then dim green
  else if x == spout
  then blue
  else if x == metal
  then mix 0.2f32 blue 0.8f32 (gray 0.5f32)
  else if x == lava
  then bright red
  else if x == napalm
  then dark orange
  else if x == turnip
  then violet
  else if x == wall
  then gray 0.4f32
  else if isFire x
  then mix (f32 (x - fire)) red (f32 (fire_end - x)) yellow
  else black -- handles 'nothing'

entry render ({generation=gen,hoods,width=ww,height=wh}: game_state [#w][#h])
             (ul_x: f32) (ul_y: f32) (s: f32) (sw: i32) (sh: i32) =
  let offset = gen % 2
  let particle_pixel (x: i32) (y: i32) =
    elemColour (worldIndex offset hoods (x,y))
  let world_pixels = map (\x -> map (particle_pixel x) (iota wh)) (iota ww)
  let ww = (shape world_pixels)[0]
  let wh = (shape world_pixels)[1]
  let screen_pixel (x: i32) (y: i32) =
    (let (x',y') = screen_point_to_world_point (ul_x,ul_y) s (sw,sh) (ww,wh) (x,y)
     in if x' >= 0 && x' < ww && y' >= 0 && y' < wh
        then unsafe world_pixels[x', y']
        else 0xFFFFFFFF)
  in map (\x -> map (screen_pixel x) (iota sh)) (iota sw)

let dist_sq(x0:f32,y0:f32) (x1:f32,y1:f32): f32 =
  (x0-x1)*(x0-x1) + (y0-y1)*(y0-y1)

let line_dist_sq (p: (f32,f32)) (v: (f32,f32)) (w: (f32,f32)): f32 =
  let l2 = dist_sq v w
  in if l2 == 0f32 then dist_sq p v
     else let t = ((#1 p - #1 v) * (#1 w - #1 v) + (#2 p - #2 v) * (#2 w - #2 v)) / l2
          let t = if t > 1f32 then 1f32
                  else if t < 0f32 then 0f32
                  else t
          in dist_sq p
((#1 v) + t * (#1 w - #1 v),
 (#2 v) + t * (#2 w - #2 v))

let f32p (x:i32,y:i32): (f32,f32) =
  (f32 x, f32 y)

let line_dist (p: (i32,i32)) (v: (i32,i32)) (w: (i32,i32)): f32 =
  f32.sqrt (line_dist_sq (f32p p) (f32p v) (f32p w))

entry add_element ({generation=gen,hoods,width=ww,height=wh}: game_state [#w][#h])
                  (ul_x: f32) (ul_y: f32) (s: f32) (sw: i32) (sh: i32)
                  (b1: i32) (b2: i32) (c1: i32) (c2: i32) (r: i32) (elem: element) =
  let from = screen_point_to_world_point (ul_x,ul_y) s (sw,sh) (ww,wh) (b1,b2)
  let to   = screen_point_to_world_point (ul_x,ul_y) s (sw,sh) (ww,wh) (c1,c2)
  let offset = gen % 2
  let hoods' =
    map (\x -> map (\y ->
                    let (ul, ur, dl, dr) = hoodQuadrants hoods[x,y]
                    let ul_p = ((x*2)+offset+0, (y*2)+offset+0)
                    let ur_p = ((x*2)+offset+1, (y*2)+offset+0)
                    let dl_p = ((x*2)+offset+0, (y*2)+offset+1)
                    let dr_p = ((x*2)+offset+1, (y*2)+offset+1)
                    in hoodFromQuadrants
                       (if line_dist ul_p from to < f32 r && ul == nothing then elem else ul)
                       (if line_dist ur_p from to < f32 r && ur == nothing then elem else ur)
                       (if line_dist dl_p from to < f32 r && dl == nothing then elem else dl)
                       (if line_dist dr_p from to < f32 r && dr == nothing then elem else dr))
         (iota h)) (iota w)
  in {generation=gen, hoods=hoods', width=ww, height=wh}

entry clear_element ({generation=gen,hoods,width=ww,height=wh}: game_state [#w] [#h])
                    (ul_x: f32) (ul_y: f32) (s: f32) (sw: i32) (sh: i32)
                    (b1: i32) (b2: i32) (c1: i32) (c2: i32) (r: i32) =
  let from = screen_point_to_world_point (ul_x,ul_y) s (sw,sh) (ww,wh) (b1,b2)
  let to   = screen_point_to_world_point (ul_x,ul_y) s (sw,sh) (ww,wh) (c1,c2)
  let offset = gen % 2
  let hoods' =
    map (\x -> map (\y ->
                    let (ul, ur, dl, dr) = hoodQuadrants hoods[x,y]
                    let ul_p = ((x*2)+offset+0, (y*2)+offset+0)
                    let ur_p = ((x*2)+offset+1, (y*2)+offset+0)
                    let dl_p = ((x*2)+offset+0, (y*2)+offset+1)
                    let dr_p = ((x*2)+offset+1, (y*2)+offset+1)
                    in hoodFromQuadrants
                       (if line_dist ul_p from to < f32 r then nothing else ul)
                       (if line_dist ur_p from to < f32 r then nothing else ur)
                       (if line_dist dl_p from to < f32 r then nothing else dl)
                       (if line_dist dr_p from to < f32 r then nothing else dr))
         (iota h)) (iota w)
  in {generation=gen, hoods=hoods', width=ww, height=wh}


entry insertable_elements() =
  [ oil
  , water
  , salt_water
  , sand
  , salt
  , stone
  , fire
  , torch
  , plant
  , spout
  , metal
  , lava
  , napalm
  , turnip
  , wall ]

entry element_name(x: element): []i32 =
  if x == nothing then "nothing"
  else if x == steam_water then "steam"
  else if x == steam_condensed then "condensate"
  else if x == oil then "oil"
  else if x == water then "water"
  else if x == salt_water then "salt water"
  else if x == sand then "sand"
  else if x == salt then "salt"
  else if x == stone then "stone"
  else if isFire x then "fire"
  else if x == torch then "torch"
  else if x == plant then "plant"
  else if x == spout then "spout"
  else if x == metal then "metal"
  else if x == lava then "lava"
  else if x == napalm then "napalm"
  else if x == turnip then "random"
  else if x == wall then "wall"
  else "unnamed element"

entry element_at ({generation=gen,hoods,width=ww,height=wh}: game_state [#w] [#h])
                 (ul_x: f32) (ul_y: f32) (s: f32) (sw: i32) (sh: i32) (b1: i32) (b2: i32) =
  let (x,y) = screen_point_to_world_point (ul_x,ul_y) s (sw,sh) (ww,wh) (b1,b2)
  let offset = gen % 2
  in worldIndex offset hoods (x,y)
