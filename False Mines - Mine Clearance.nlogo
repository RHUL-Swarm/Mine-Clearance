breed [searchers searcher]
breed [mines mine]
breed [malicious_entities malicious_entitity]
breed [false_mines false_mine]

patches-own
[
  scent
]

searchers-own
[
  current_state ; 0 = foraging, 1 = scent following, 2 = waiting
  x-destination_heading_for  ; initial destination assuming does not find mine or scent
  y-destination_heading_for  ; initial destination assuming does not find mine or scent

  x_coordinate_reached
  y_coordinate_reached

  scent_concentration
  waiting_time

  mine_found
  scent_release
  scent_following
]

turtles-own
[
  x-position
  y-position
]

mines-own
[
  number_of_searchers_present
]

globals
[
  freeze_state
  stuck_state
  good_detection
  false_positives
]

to setup
  clear-all
  draw_boundaries
  reset-ticks
  place_false_mines
  place_mines
  place_searchers
  ask patches [set scent 0]
  set freeze_state FALSE
  set stuck_state FALSE
  set good_detection 0
  set false_positives 0

end

to go_single
  mine_check   ; Needs to be first to re-distribute any scent after a refresh of patch scent values
  scent_check
  move_searchers
  searcher_location_check ; has the searcher reached the random destination required or a mine location
  wait_check
  disarmed_check
  malicious_entity_check
  colour_check_patches
  mines_remaining
  stuck_check

  if (freeze_state = TRUE)
  [
    stop
  ]

  if (stuck_state = TRUE)
  [
    stop
  ]

  tick
end

to record_data
  file-type ticks
  file-type " , "
  file-type count searchers with [current_state = 0]
  file-type " , "
  file-type count searchers with [current_state = 1]
  file-type " , "
  file-type count searchers with [current_state = 2]
  file-type " , "
  file-type count searchers with [current_state = 3]
  file-type " , "
end

to malicious_scent_release
  ask malicious_entities
  [
    ask patch-here [set pcolor YELLOW]
    release_scent
  ]
end

to stuck_check
  if (ticks > max_tick_count)
  [
    set stuck_state TRUE
    print (word "STUCK!")
  ]
end

to freeze_check
  if all? searchers [current_state = 2]
  [
    if all? mines [number_of_searchers_present < 4]
    [
      set freeze_state TRUE
      print (word "FREEZE!")
    ]
  ]

end

to mines_remaining
  set number_of_mines_remaining count mines
end

to-report num-date  ; current date in numerical format, yyyy-mm-dd
  let $dt substring date-and-time 16 27
  report (word (substring $dt 7 11)           ; yyyy
           "-" (month-num substring $dt 3 6)  ; mm
           "-" (substring $dt 0 2) )          ; dd
end

to-report month-num [ #mon ]
  let $index 1 + position #mon
    ["Jan""Feb""Mar""Apr""May""Jun""Jul""Aug""Sep""Oct""Nov""Dec"]
  report substring (word (100 + $index)) 1 3  ; force 2-digit string
end

to go_exp

  let temp_restart FALSE ; TRUE/FALSE

  let new_file_name_1 ("")
  let new_file_name_2 ("")
  let date ""
  set date num-date

  let rounds 0
  let freeze_event_count 0
  let stuck_count 0
  let ave_count_for_freezes 0
  let ave_count_for_sticking 0
  let number_of_rounds 30
  let initial_number_of_searchers 30
  let initial_number_of_mines 10
  set number_of_searchers 30
  set number_of_mines_remaining 10

  let mine_starting_amount 30

  let count_to_clear_all_mines 0
  let ave_count_to_clear_all_mines 0

  if (temp_restart = TRUE)
  [
    set number_of_searchers 30 ; allow to restart from location
    set temp_restart FALSE
  ]

  let to_many_freezes FALSE

  set new_file_name_1 (word "Searchers_" number_of_searchers "__Mines_" mine_starting_amount "_" date ".csv")
  if (file-exists? new_file_name_1)
  [
    file-open new_file_name_1
    file-close
    file-delete new_file_name_1
  ]
  print (word "new_file_name: " new_file_name_1)
  file-open new_file_name_1

  while [mine_starting_amount < 101]
  [
    file-print " "
    file-print " "
    file-print " "
    file-print "Number of Mines: "
    file-write mine_starting_amount
    file-print " "
    file-print " "
    file-print "No of Searchers , Ave time to clear , Freezes , Sticks , Too Many Sticks "; , False Neg , Time Outs"

    while [number_of_searchers < 101]
      [
        while [((rounds < number_of_rounds) and (to_many_freezes = FALSE))]
        [
          set number_of_mines_remaining mine_starting_amount
          setup
          print (word "rounds: " rounds)

          while [((number_of_mines_remaining > 0) and (freeze_state = FALSE) and (stuck_state = FALSE))]
          [
              go_single
          ]

          ifelse ((freeze_state = FALSE) and (stuck_state = FALSE))
          [
            set count_to_clear_all_mines (count_to_clear_all_mines + (ticks))
            set rounds (rounds + 1)
          ]
          [
            ifelse (freeze_state = TRUE)
            [
              set freeze_event_count freeze_event_count + 1
              set freeze_state FALSE
              if (freeze_event_count > Freeze_Count_Max_Amount)
              [
                SET to_many_freezes TRUE
              ]
            ]
            [
              set stuck_count stuck_count + 1
              set stuck_state FALSE
            ]
          ]

        ]

        set ave_count_to_clear_all_mines (count_to_clear_all_mines / number_of_rounds)
        set ave_count_for_freezes (freeze_event_count / number_of_rounds)
        set ave_count_for_sticking (stuck_count / number_of_rounds)

        file-type number_of_searchers
        file-type " ,"
        file-type ave_count_to_clear_all_mines
        file-type " ,"
        file-type ave_count_for_freezes
        file-type " ,"
        file-type ave_count_for_sticking
        file-type " ,"
        file-type to_many_freezes
        file-print " "
        file-flush

        set rounds 0
        set count_to_clear_all_mines 0
        set ave_count_to_clear_all_mines 0

        set freeze_event_count 0
        set stuck_count 0

        set to_many_freezes FALSE

        set number_of_searchers number_of_searchers + 10
      ]
      set number_of_searchers initial_number_of_searchers

      set mine_starting_amount mine_starting_amount + 10
  ]

  file-close-all

end

to wait_check

  let refresh FALSE

  ask searchers
  [
    if (waiting_time > 0 )
    [
      set waiting_time (waiting_time - 1)
    ]
    if ((current_state = 2) AND (waiting_time = 0))
    [
      set current_state 3
      set refresh TRUE
      if (mine_found = TRUE)
      [
        set mine_found FALSE
      ]
    ]
  ]

  if (refresh = TRUE)
  [
    print (word "refresh on wait")
    ask patches
    [
      set scent 0
    ] ; To ensure this scent is removed and background colour set to black. Mine check command will return the other scents
    ask searchers
    [
      if (current_state != 3)
      [
        set current_state 0
      ]
    ]
  ]
end

to malicious_entity_check

  let refresh FALSE

  let good_detection_local_count FALSE
  let false_positive_local_count FALSE

  ask searchers
  [
    if ((current_state != 3) AND (count searchers-here > 4) AND (ticks > 30)) ; ticks allow to move away from start point before can reach first malicious entity
    [
      ask searchers-here
      [
        set current_state 3
      ]

      ifelse any? false_mines-here
      [
        set good_detection_local_count TRUE
      ]
      [
        set false_positive_local_count TRUE
      ]
      set refresh TRUE
    ]
  ]

  if (refresh = TRUE)
  [
    ask patches
    [
      set scent 0
    ] ; To ensure this scent is removed and background colour set to black. Mine check command will return the other scents
    ask searchers
    [
      if (current_state != 3) ; to ensure that state 3 mines are not immediately returned to state 0 and therefore not able to return to malicious entity (false_mine)
      [
        set current_state 0 ; to ensure that not all mines are believed disarmed the main routine checks for a mine presence before allowing movement
      ]

      if (mine_found = TRUE)
      [
        set mine_found FALSE
      ]
    ]
  ]
  if(good_detection_local_count = TRUE)
  [
    set good_detection (good_detection + 1)
  ]

  if(false_positive_local_count = TRUE)
  [
    set false_positives (false_positives + 1)
  ]
end

to disarmed_check

  let refresh FALSE

  ask mines
  [
    if (count searchers-here >= 4)
    [
      ask searchers-here
      [
        set current_state 0
      ]
      set refresh TRUE
      die
    ]
  ]

  if (refresh = TRUE)
  [
    ask patches
    [
      set scent 0
    ] ; To ensure this scent is removed and background colour set to black. Mine check command will return the other scents
    ask searchers
    [
      if (current_state != 3)
      [
        set current_state 0
      ]
      if (mine_found = TRUE)
      [
        set mine_found FALSE
      ]

    ]
  ]
end

to colour_check_patches
  ask patches with [(pxcor < max-pxcor) AND (pxcor > min-pxcor) AND (pycor < max-pycor) AND (pycor > min-pycor)]
  [
    set pcolor scale-color green scent 0.1 10
  ]
end

to move_searchers
  ask searchers
  [
    if ((current_state = 0) or (current_state = 3)) ; i.e. Foraging or moving away from malicios activity
    [
      ifelse (x_coordinate_reached = TRUE)
      [
        move_y_direction
      ]
      [
        ifelse (y_coordinate_reached = TRUE)
        [
          move_x_direction
        ]
        [
          ifelse (random 2 = 0)
          [
            move_x_direction
          ]
          [
            move_y_direction
          ]
        ]
      ]
    ]
  ]

end

to move_x_direction

  ifelse (x-destination_heading_for = xcor)
  [
    set x_coordinate_reached TRUE
  ]
  [
    ifelse (x-destination_heading_for > xcor) [set heading 90] [set heading 270]
    fd 1
    if (xcor > min-pxcor + 1) ; prevents rounding to zero
    [
      set xcor round xcor
    ]

  ]
end

to move_y_direction

  ifelse (y-destination_heading_for = ycor)
  [
    set y_coordinate_reached TRUE
  ]
  [
    ifelse (y-destination_heading_for > ycor) [set heading 0] [set heading 180]
    fd 1
    if (ycor > min-pycor + 1)
    [
      set ycor round ycor
    ]
  ]
end

to check_wall_collision

  if ([pcolor] of patch-ahead 1 != BLUE) [stop]

  rt 180

end

to scent_check
  ask searchers
  [
    if (current_state != 3) ; i.e. not suspected malicious activity and not moving away
    [
      let scent_ahead scent_at_angle 0
      let scent_right scent_at_angle 90
      let scent_left scent_at_angle -90
      ifelse ((scent_ahead > 0) or (scent_right > 0) or (scent_left > 0)) ; If scent is located around searcher
      [
        if (current_state = 0) ; current state searching
        [
          set current_state 1 ; set to scent following
        ]
      ]
      [
        if (([scent] of patch-here = 0) AND (current_state != 0))
        [
          set current_state 0 ; set to foraging
          if (mine_found = TRUE)
          [
            set mine_found FALSE
          ]
        ]
      ]

      if (current_state = 1)
      [
        ifelse (([scent] of patch-here > scent_ahead) AND ([scent] of patch-here > scent_right) AND ([scent] of patch-here > scent_left))
        [  ; suspect malicious activity

          set current_state 3 ; i.e. suspected malicious activity and moving away

          ifelse any? malicious_entities-here
          [
            set good_detection (good_detection + 1)
          ]
          [
            set false_positives (false_positives + 1)
          ]
        ]
        [  ; suspect no malicious activity
          if (scent_right > scent_ahead) or (scent_left > scent_ahead)
          [
            ifelse scent_right > scent_left
            [ rt 90 ]
            [ lt 90 ]
          ]
        ]

        check_wall_collision
        fd 1
      ]
    ]
    if (current_state = 3) ; i.e. suspected malicious activity and moving away
    [
      if ([scent] of patch-here = 0) ; moved away from any scent influence
      [
        set current_state 0 ; foraging
      ]
    ]
  ]
end

to-report scent_at_angle [angle]
  let p patch-right-and-ahead angle 1
  if p = nobody [ report 0 ]
  report [scent] of p
end

to searcher_location_check

  mine_check
  destination_check

end

to destination_check
  ask searchers
  [
    if ((x_coordinate_reached = TRUE) AND (y_coordinate_reached = TRUE))
    [
      set_destination_to_head_for
    ]
  ]
end


to mine_check
  let patch_refresh FALSE
  ask searchers
  [
    if (((any? mines-here) OR (any? false_mines-here)) AND (current_state != 3)) ; i.e. not suspected malicious activity and not moving away
    [
      if (current_state != 2) ; First searcher to find mine / others come along and find mine
      [
        set current_state 2 ; waiting
        ask patch-here [set pcolor GREEN]
        release_scent
        set patch_refresh TRUE
        if (mine_found = FALSE)
        [
          set mine_found TRUE
          set waiting_time wait_time
        ]
      ]
    ]
  ]
  if (patch_refresh = TRUE)
  [
    colour_check_patches
  ]

end

to release_scent ; tidy up

  let possible_area patches in-radius scent_radius
  let colour_required GREEN

  let current_scent 100
  let scent_value current_scent

  let centre_point patch-here
  ask centre_point [set scent (current_scent + scent)]

  let completed_search FALSE
    let wall_found  FALSE

    let test_patch patch-at 0 0
    let x-offset 0
    let y-offset 0

    let check 0

    while [completed_search = FALSE]
    [
      ; NORTH
      set check check_North 0 1 possible_area current_scent

      ; SOUTH
      set check check_South 0 -1 possible_area current_scent

      ; EAST
      set check check_East 1 0 possible_area current_scent

      ; WEST
      set check check_West -1 0 possible_area current_scent

      ; CHECK TO THE NORTH EAST
      check_North_East 1 1 possible_area current_scent

      ; CHECK TO THE SOUTH EAST
      check_South_East 1 -1 possible_area current_scent

      ; CHECK TO THE SOUTH WEST
      check_South_West -1 -1 possible_area current_scent

      ; CHECK TO THE NORTH WEST
      check_North_West -1 1 possible_area current_scent

      set completed_search TRUE
    ]
end

to-report check_North [x-offset y-offset possible_area start_scent]

  let temp_scent (start_scent ^ base_number)

  while [([pcolor] of patch-at x-offset y-offset != blue) and (member? (patch-at x-offset y-offset) possible_area)]
  [
    ask patch-at x-offset y-offset [set scent (temp_scent + scent)]
    set temp_scent (temp_scent ^ base_number)
    set y-offset y-offset + 1
  ]

  ifelse ([pcolor] of patch-at x-offset y-offset = blue)
  [
    report -2
  ]
  [
    report -1
  ]
end

to-report check_South [x-offset y-offset possible_area start_scent]
  let temp_scent (start_scent ^ base_number)

  while [([pcolor] of patch-at x-offset y-offset != blue) and (member? (patch-at x-offset y-offset) possible_area)]
  [
    ask patch-at x-offset y-offset [set scent (temp_scent + scent)]
    set temp_scent (temp_scent ^ base_number)
    set y-offset y-offset - 1
  ]

  ifelse ([pcolor] of patch-at x-offset y-offset = blue)
  [
    report -2
  ]
  [
    report -1
  ]
end

to-report check_East [x-offset y-offset possible_area start_scent]
  let temp_scent (start_scent ^ base_number)

  while [([pcolor] of patch-at x-offset y-offset != blue) and (member? (patch-at x-offset y-offset) possible_area)]
  [
    ask patch-at x-offset y-offset [set scent (temp_scent + scent)]
    set temp_scent (temp_scent ^ base_number)
    set x-offset x-offset + 1
  ]

  ifelse ([pcolor] of patch-at x-offset y-offset = blue)
  [
    report -2
  ]
  [
    report -1
  ]
end

to-report check_West [x-offset y-offset possible_area start_scent]
  let temp_scent (start_scent ^ base_number)

  while [([pcolor] of patch-at x-offset y-offset != blue) and (member? (patch-at x-offset y-offset) possible_area)]
  [
    ask patch-at x-offset y-offset [set scent (temp_scent + scent)]
    set temp_scent (temp_scent ^ base_number)
    set x-offset x-offset - 1
  ]

  ifelse ([pcolor] of patch-at x-offset y-offset = blue)
  [
    report -2
  ]
  [
    report -1
  ]
end


to check_North_West [x-offset y-offset possible_area start_scent]
    let x-run 0
    let y-run 0
    let start_offset 0
    let x-count 0
    let y-count 0
    let angle_offset 270

    let temp_scent start_scent

    let continue TRUE

    while [(continue = TRUE) and ([pcolor] of patch-at x-offset y-offset != blue) and ((pxcor + x-offset) > min-pxcor) and ((pycor + y-offset) < max-pycor) and (member? (patch-at x-offset y-offset) possible_area)]
    [
        while[(continue = TRUE) and (member? (patch-at x-offset y-offset) possible_area) and ([pcolor] of patch-at x-offset y-offset != blue)]
        [
          set x-count x-count + 1

          set x-run check_North x-offset y-offset possible_area temp_scent
          if ((x-run = -2) and ([pcolor] of patch-at (x-offset - 1) y-offset = blue))
          [
            set continue FALSE
          ]
          set x-offset x-offset - 1
          set temp_scent (temp_scent ^ base_number)
        ]

        while[(member? (patch-at x-offset y-offset) possible_area) and (continue = FALSE)]
        [
          set continue TRUE
        ]

        while[(continue = TRUE) and (member? (patch-at x-offset y-offset) possible_area) and ([pcolor] of patch-at x-offset y-offset != blue)]
        [
          set y-count y-count + 1

          set y-run check_West x-offset y-offset possible_area temp_scent
          if (y-run = -2)
          [
            set continue FALSE
          ]
          set y-offset y-offset + 1 ; eventually hits wall or area limits
          set temp_scent (temp_scent ^ base_number)
        ]
    ]
end

to check_North_East [x-offset y-offset possible_area start_scent]
    let x-run 0
    let y-run 0
    let start_offset 0
    let x-count 0
    let y-count 0
    let angle_offset 0

    let temp_scent start_scent ; (start_scent ^ base_number)

    let continue TRUE

    while [(continue = TRUE) and ([pcolor] of patch-at x-offset y-offset != blue) and ((pxcor + x-offset) < max-pxcor) and ((pycor + y-offset) < max-pycor) and (member? (patch-at x-offset y-offset) possible_area)]
    [
        while[(continue = TRUE) and (member? (patch-at x-offset y-offset) possible_area) and ([pcolor] of patch-at x-offset y-offset != blue)]
        [
          set x-count x-count + 1

          set x-run check_North x-offset y-offset possible_area temp_scent

          if ((x-run = -2) and ([pcolor] of patch-at (x-offset + 1) y-offset = blue))
          [
            set continue FALSE
          ]
          set x-offset x-offset + 1
          set temp_scent (temp_scent ^ base_number)
        ]

        while[(member? (patch-at x-offset y-offset) possible_area) and (continue = FALSE)]
        [
          set continue TRUE
        ]

        while[(continue = TRUE) and (member? (patch-at x-offset y-offset) possible_area) and ([pcolor] of patch-at x-offset y-offset != blue)]
        [
          set y-count y-count + 1

          set y-run check_East x-offset y-offset possible_area temp_scent
          if (y-run = -2)
          [
            set continue FALSE
          ]
          set y-offset y-offset + 1 ; eventually hits wall or area limits
          set temp_scent (temp_scent ^ base_number)
        ]
    ]
end

to check_South_East [x-offset y-offset possible_area start_scent]
    let x-run 0
    let y-run 0
    let start_offset 0
    let x-count 0
    let y-count 0
    let angle_offset 90

    let temp_scent start_scent

    let continue TRUE

    while [(continue = TRUE) and ([pcolor] of patch-at x-offset y-offset != blue) and ((pxcor + x-offset) < max-pxcor) and ((pycor + y-offset) > min-pycor) and (member? (patch-at x-offset y-offset) possible_area)]
    [
        while[(continue = TRUE) and (member? (patch-at x-offset y-offset) possible_area) and ([pcolor] of patch-at x-offset y-offset != blue)]
        [
          set x-count x-count + 1

          set x-run check_South x-offset y-offset possible_area temp_scent
          if ((x-run = -2) and ([pcolor] of patch-at (x-offset + 1) y-offset = blue))
          [
            set continue FALSE
          ]
          set x-offset x-offset + 1
          set temp_scent (temp_scent ^ base_number)
        ]

        while[(member? (patch-at x-offset y-offset) possible_area) and (continue = FALSE)]
        [
          set continue TRUE
        ]

        while[(continue = TRUE) and (member? (patch-at x-offset y-offset) possible_area) and ([pcolor] of patch-at x-offset y-offset != blue)] ; Does not get into here (not in poss area) so does not get continue set to FALSE
        [
          set y-count y-count + 1

          set y-run check_East x-offset y-offset possible_area temp_scent
          if (y-run = -2)
          [
            set continue FALSE
          ]
          set y-offset y-offset - 1 ; eventually hits wall or area limits
          set temp_scent (temp_scent ^ base_number)
        ]
    ]
end

to check_South_West [x-offset y-offset possible_area start_scent]

    let x-run 0
    let y-run 0
    let start_offset 0
    let angle_offset 180

    let temp_scent start_scent

    let continue TRUE

    while [(continue = TRUE) and ([pcolor] of patch-at x-offset y-offset != blue) and ((pxcor + x-offset) > min-pxcor) and ((pycor + y-offset) > min-pycor) and (member? (patch-at x-offset y-offset) possible_area)]
    [
        while[(continue = TRUE) and (member? (patch-at x-offset y-offset) possible_area) and ([pcolor] of patch-at x-offset y-offset != blue)]
        [

          set x-run check_South x-offset y-offset possible_area temp_scent
          if ((x-run = -2) and ([pcolor] of patch-at (x-offset - 1) y-offset = blue))
          [
            set continue FALSE
          ]
          set x-offset x-offset - 1
          set temp_scent (temp_scent ^ base_number)
        ]

        while[(member? (patch-at x-offset y-offset) possible_area) and (continue = FALSE)]
        [
          set continue TRUE
        ]

        while[(continue = TRUE) and (member? (patch-at x-offset y-offset) possible_area) and ([pcolor] of patch-at x-offset y-offset != blue)]
        [
          set y-run check_West x-offset y-offset possible_area temp_scent
          if (y-run = -2)
          [
            set continue FALSE
          ]
          set y-offset y-offset - 1 ; eventually hits wall or area limits
          set temp_scent (temp_scent ^ base_number)
        ]
    ]

end


to fill_in_due_to_wall [start_offset angle_offset distance_a distance_b colour_required]

    let completed_search FALSE
    let possible_area patches in-radius scent_radius

    let direction_step (45 / (scent_radius + 1))
    let step_distance 1

    let start_angle_offset 0
    let end_angle_offset 0

    set start_angle_offset safe-atan distance_a scent_radius

    set start_angle_offset (floor(start_angle_offset / direction_step) * direction_step)

    let direction_check (angle_offset + start_angle_offset)

     while [completed_search = FALSE]
    [
       while [([pcolor] of patch-at-heading-and-distance direction_check step_distance != blue) and (member? (patch-at-heading-and-distance direction_check step_distance) possible_area)]
       [
         ask patch-at-heading-and-distance direction_check step_distance [set pcolor colour_required]
         set step_distance step_distance + 1
       ]

       set step_distance 1
       set direction_check (direction_check + (direction_step))

       if ((direction_check - angle_offset) >= 90)
       [
         set completed_search TRUE
       ]
    ]
end

to-report check_offset [x-run y-run]

  let start_offset 0

    ifelse (x-run != -1) ; if x-run found a wall
    [
      ifelse (y-run != -1) ; if x-run and y-run found a wall
      [
        ifelse (x-run <= y-run)
        [
          set start_offset x-run ; if x-run the smallest
        ]
        [
          set start_offset y-run ; if y-run smallest number
        ]
      ]
      [
        set start_offset x-run ; y-run did not find a wall but x-run did
      ]
    ]
    [
      ifelse (y-run != -1) ; if x-run and y-run found a wall
      [
        set start_offset y-run ; x-run did not find a wall but y-run did
      ]
      [
        set start_offset -1
      ]
    ]
    report start_offset
end

;; Avoid atan 0 0 problem. Essential for Behavior Space
to-report safe-atan [x y] report ifelse-value (x = 0 and y = 0) [0][atan x y] end

to set_destination_to_head_for
  set x-destination_heading_for random-pxcor
  set y-destination_heading_for random-pycor

  if ((x-destination_heading_for > (max-pxcor - 1)) or ((x-destination_heading_for < min-pxcor + 1)) or (y-destination_heading_for > (max-pycor - 1)) or ((y-destination_heading_for < min-pycor + 1))) ; Limit check to make sure in bounds
  [
    set_destination_to_head_for
  ]

  set x_coordinate_reached FALSE
  set y_coordinate_reached FALSE

end

to draw_boundaries
  ; draw left and right walls
  ask patches with [pxcor = max-pxcor]
    [ set pcolor BLUE ]
  ask patches with [pxcor = min-pxcor]
    [ set pcolor BLUE ]
  ; draw top and bottom walls
  ask patches with [pycor = max-pycor]
    [ set pcolor BLUE ]
  ask patches with [pycor = min-pycor]
    [ set pcolor BLUE ]
end

to randomly_position_entity
    set xcor random-pxcor
    set ycor random-pycor

    if ([pcolor] of patch-here = BLUE)
    [
      randomly_position_entity
    ]

    if ((xcor > (max-pxcor - 1)) or ((xcor < min-pxcor + 1)) or (ycor > (max-pycor - 1)) or ((ycor < min-pycor + 1))) ; Secondary limit check to make sure in bounds
    [
      randomly_position_entity
    ]

    if(any? other turtles-here)
    [
      randomly_position_entity
    ]
end

to place_mines

  create-mines (number_of_mines_remaining)
  [
    set color RED
    set shape "target"
    set size 1

    randomly_position_entity

    set pcolor RED
  ]


end

to place_searchers

  create-searchers (number_of_searchers)
  [
    set color BLUE
    set size 1
    set xcor 1
    set ycor 1
    set mine_found FALSE
    set waiting_time 0
    set current_state 3 ; 0   3 to allow them to exit the start point
  ]

  ask searchers
  [
    set_destination_to_head_for
  ]
]
end

to place_malicious_entities

    let malicious_x_points []
    let malicious_y_points []
    let malicious_count 0


    set malicious_x_points [25 50 75 25 50 75 25 50 75]
    set malicious_y_points [25 25 25 50 50 50 75 75 75]


    let number-of-malicious-entities (length malicious_x_points)

    let number_of_mal_entities number-of-malicious-entities

    set malicious_count 0

    while [number_of_mal_entities > 0]
    [
      create-malicious_entities 1
      [
        set color YELLOW
        set shape "circle 2"
        set size 1

        set xcor item malicious_count malicious_x_points
        set ycor item malicious_count malicious_y_points
      ]

      set number_of_mal_entities (number_of_mal_entities - 1)
      set malicious_count (malicious_count + 1)
    ]

end

to place_false_mines

    let malicious_x_points []
    let malicious_y_points []
    let malicious_count 0

    set malicious_x_points [25 50 75 25 50 75 25 50 75]
    set malicious_y_points [25 25 25 50 50 50 75 75 75]


    let number-of-false_mines (length malicious_x_points)

    let number_of_mal_entities number-of-false_mines

    set malicious_count 0

    while [number_of_mal_entities > 0]
    [
      create-false_mines 1
      [
        set color YELLOW
        set shape "circle 2"
        set size 1

        set xcor item malicious_count malicious_x_points
        set ycor item malicious_count malicious_y_points
      ]

      set number_of_mal_entities (number_of_mal_entities - 1)
      set malicious_count (malicious_count + 1)
    ]

end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
730
551
-1
-1
5.0
1
10
1
1
1
0
0
0
1
0
101
0
101
0
0
1
ticks
30.0

BUTTON
40
84
104
117
Setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
42
131
150
164
Go Single Run
go_single
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
20
229
192
262
number_of_searchers
number_of_searchers
1
100
30
1
1
NIL
HORIZONTAL

SLIDER
21
272
193
305
base_number
base_number
0
1
0.5
0.01
1
NIL
HORIZONTAL

SLIDER
27
329
199
362
scent_radius
scent_radius
0
10
5
1
1
NIL
HORIZONTAL

SLIDER
22
386
194
419
wait_time
wait_time
1
1000
500
1
1
NIL
HORIZONTAL

MONITOR
47
509
151
554
Mines Remaining
number_of_mines_remaining
17
1
11

SLIDER
27
558
235
591
number_of_mines_remaining
number_of_mines_remaining
0
100
18
1
1
NIL
HORIZONTAL

BUTTON
42
179
154
212
Go Experiment
go_exp
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

INPUTBOX
24
431
179
491
max_tick_count
100000
1
0
Number

INPUTBOX
280
573
435
633
Freeze_Count_Max_Amount
500
1
0
Number

MONITOR
445
574
549
619
Good Detections
good_detection
17
1
11

MONITOR
560
574
654
619
False Positives
false_positives
17
1
11

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.3.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
