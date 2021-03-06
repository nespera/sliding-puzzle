module App where

import Graphics.Element exposing (Element)
import Dict exposing (Dict)
import Graphics.Collage
import Signal.Extra
import Keyboard
import Window
import String
import Maybe
import Touch
import Board
import Utils
import Debug


-- MODEL

type alias Model =
  Board.Model


initialWidth : Int
initialWidth =
  let
    defaultBoardWidth = 3
    minBoardWidth = 2
    maxBoardWidth = 10
  in
    Utils.dictGetInt "width" defaultBoardWidth minBoardWidth maxBoardWidth queryParams


initialHeight : Int
initialHeight =
  let
    defaultBoardHeight = 3
    minBoardHeight = 2
    maxBoardHeight = 10
  in
    Utils.dictGetInt "height" defaultBoardHeight minBoardHeight maxBoardHeight queryParams


initialTileSize : (Int, Int) -> Int
initialTileSize windowDimensionsValue =
  getTileSize (initialWidth, initialHeight) windowDimensionsValue


initialShuffle : Int
initialShuffle =
  let
    defaultShuffle = (initialWidth * initialHeight) ^ 2
    minShuffle = 0
    maxShuffle = 20000
  in
    Utils.dictGetInt "shuffle" defaultShuffle minShuffle maxShuffle queryParams  


getTileSize : (Int, Int) -> (Int, Int) -> Int
getTileSize (boardWidth, boardHeight) (windowWidth, windowHeight) =
  let
    padding = 40
    tileWidth = (windowWidth - padding) // boardWidth
    tileHeight = (windowHeight - padding) // boardHeight
    
    defaultTileSize = min tileWidth tileHeight |> min maxTileSize
    minTileSize = 5
    maxTileSize = 200
  in
    Utils.dictGetInt "size" defaultTileSize minTileSize maxTileSize queryParams


defaultGoal : String
defaultGoal =
  let
    goal = [1..(initialWidth * initialHeight - 1)]
      |> List.map toString
      |> String.join ","
  in
    goal ++ ","


initialStart : String
initialStart =
  Dict.get "start" queryParams
    |> Maybe.withDefault defaultGoal


initialGoal : String
initialGoal =
  Dict.get "goal" queryParams
    |> Maybe.withDefault defaultGoal


queryParams : Dict String String
queryParams =
  Utils.queryParams locationSearch


initialModel : (Int, Int) -> Model
initialModel windowDimensionsValue =
  let
    tileSpacing = 1
  in
    Board.init initialSeed initialWidth initialHeight (initialTileSize windowDimensionsValue) tileSpacing initialStart initialGoal
      |> Board.update (Board.Shuffle initialShuffle)


-- UPDATE

type Action
  = NoOp
  | ArrowLeft
  | ArrowRight
  | ArrowUp
  | ArrowDown
  | Click (Int, Int) (Int, Int)
  | WindowResize (Int, Int)


update : Action -> Model -> Model
update action ({ boardWidth, boardHeight, tileSize } as model) =
  case action of
    ArrowLeft ->
      model |> Board.update (Board.Move Board.Left)

    ArrowRight ->
      model |> Board.update (Board.Move Board.Right)

    ArrowUp ->
      model |> Board.update (Board.Move Board.Up)

    ArrowDown ->
      model |> Board.update (Board.Move Board.Down)

    Click (clickX, clickY) (windowWidth, windowHeight) ->
      let
        boardTopLeftX = (windowWidth - boardWidth * tileSize) // 2
        boardTopLeftY = (windowHeight - boardHeight * tileSize) // 2

        dx = clickX - boardTopLeftX
        dy = clickY - boardTopLeftY

        row = dy // tileSize
        column = dx // tileSize
      in
        if dx < 0 || row >= boardHeight || dy < 0 || column >= boardWidth
          then model
          else model |> Board.update (Board.MoveTile (row, column))
    
    WindowResize dimensions ->
      { model | tileSize <- getTileSize (boardWidth, boardHeight) dimensions }

    _ ->
      model


-- VIEW

view : (Int, Int) -> Model -> Element
view (windowWidth, windowHeight) model =
  Board.view model
    |> Graphics.Collage.collage windowWidth windowHeight


-- PORTS

port initialSeed : Int
port locationSearch : String


-- SIGNALS

windowDimensions : Signal (Int, Int)
windowDimensions =
  Window.dimensions


windowResize : Signal Action
windowResize =
  Signal.map WindowResize windowDimensions


clicks : Signal Action
clicks =
  let
    createClick { x, y } dimensions =
      Click (x, y) dimensions
  in
    Signal.map2 createClick Touch.taps windowDimensions
      |> Signal.sampleOn Touch.taps


arrows : Signal Action
arrows =
  let
    toAction arrow =
      if | arrow == { x = -1, y = 0 } -> ArrowLeft
         | arrow == { x = 1, y = 0 } -> ArrowRight
         | arrow == { x = 0, y = 1 } -> ArrowUp
         | arrow == { x = 0, y = -1 } -> ArrowDown
         | otherwise -> NoOp
  in
    Keyboard.arrows
      |> Signal.map toAction
      |> Signal.filter (\a -> a /= NoOp) NoOp


input : Signal Action
input =
  Signal.mergeMany
    [ windowResize
    , arrows
    , clicks
    ]


model : Signal Model
model =
  let
    getInitialModel initialInput =
      case initialInput of
        WindowResize dimensions ->
          initialModel dimensions

        _ ->
          Debug.crash "initial action should be WindowResize"
  in
    Signal.Extra.foldp' update getInitialModel input


-- MAIN

main : Signal Element
main =
  Signal.map2 view windowDimensions model
