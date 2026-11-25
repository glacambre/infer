(*
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *)

open! IStd
open RustMir2TextualTest

(* An example test *)
let%expect_test "global places" =
  let source =
    {|
const X : i32 = 5;
const Y : i32 = succ(X);


const fn succ(i : i32) -> i32 {
    i + 1
}

#[allow(unused)]
fn main() {
    let eleven = X + Y;
}
|}
  in
  test source ;
  [%expect
    {|
    .source_language = "Rust"

    define dummy::succ(i_1: int) : int {
      local var_0: int, var_2: int, var_3: int
      #node_0:
          n0:int = load &i_1
          store &var_2 <- n0:int
          n1:int = load &var_2
          store &var_3 <- __sil_plusa_int(n1, 1):int
          n2:int = load &var_3
          store &var_0 <- n2:int
          n3:int = load &var_0
          ret n3

    }

    define dummy::main() : void {
      local var_0: void, eleven_1: int, var_2: int
      #node_0:
          store &var_0 <- null:void
          n0:int = load &GLOBAL@dummy::X
          n1:int = load &GLOBAL@dummy::Y
          store &var_2 <- __sil_plusa_int(n0, n1):int
          n2:int = load &var_2
          store &eleven_1 <- n2:int
          store &var_0 <- null:void
          n3:void = load &var_0
          ret n3

    }

    define dummy::X() : int {
      local var_0: int
      #node_0:
          store &var_0 <- 5:int
          n0:int = load &var_0
          ret n0

    }

    define dummy::Y() : int {
      local var_0: int
      #node_0:
          n0:int = load &GLOBAL@dummy::X
          n1 = dummy::succ(n0)
          store &var_0 <- n1:int
          jmp node_2
          .handlers node_1

      #node_1:
          throw "UnwindResume"

      #node_2:
          n2:int = load &var_0
          ret n2

    }

    global GLOBAL@dummy::X: int = [Some dummy::X()]

    global GLOBAL@dummy::Y: int = [Some dummy::Y()]
    |}]


(* With [--consts=values], Charon gives a global its evaluated value instead of a call to its
   initializer. A value that we cannot translate, such as a struct, leaves the global without an
   initializer instead of aborting the translation of the module. *)
let%expect_test "global values" =
  let source =
    {|
struct Point {
    x: i32,
    y: i32,
}

const ORIGIN: Point = Point { x: 0, y: 2 };
const SEVEN: i32 = 7;

#[allow(unused)]
fn main() {
    let x = ORIGIN.x + ORIGIN.y + SEVEN;
}
|}
  in
  test ~args:"--consts=values" source ;
  [%expect
    {|
    [WARNING] Could not translate the value of dummy::ORIGIN:
     [REASON]: only literals and initializer calls are supported
    .source_language = "Rust"

    type dummy::Point = {x: int; y: int}

    define dummy::main() : void {
      local var_0: void, x_1: int, var_2: int, var_3: int, var_4: dummy::Point, var_5: int, var_6: dummy::Point, var_7: int, var_8: int
      #node_0:
          store &var_0 <- null:void
          n0:dummy::Point = load &GLOBAL@dummy::ORIGIN
          store &var_4 <- n0:dummy::Point
          n1:int = load &var_4.dummy::Point.x
          store &var_3 <- n1:int
          n2:dummy::Point = load &GLOBAL@dummy::ORIGIN
          store &var_6 <- n2:dummy::Point
          n3:int = load &var_6.dummy::Point.y
          store &var_5 <- n3:int
          n4:int = load &var_3
          n5:int = load &var_5
          store &var_7 <- __sil_plusa_int(n4, n5):int
          n6:int = load &var_7
          store &var_2 <- n6:int
          n7:int = load &var_2
          n8:int = load &GLOBAL@dummy::SEVEN
          store &var_8 <- __sil_plusa_int(n7, n8):int
          n9:int = load &var_8
          store &x_1 <- n9:int
          store &var_0 <- null:void
          n10:void = load &var_0
          ret n10

    }

    global GLOBAL@dummy::ORIGIN: dummy::Point

    global GLOBAL@dummy::SEVEN: int = [Some 7]
    |}]


let%expect_test "external function declaration" =
  test
    {|
unsafe extern "C" {
    fn external(x: i32) -> i32;
}

fn main() {
    let _ = unsafe { external(42) };
}
|} ;
  [%expect
    {|
    .source_language = "Rust"

    define dummy::main() : void {
      local var_0: void, var_1: int
      #node_0:
          store &var_0 <- null:void
          n0 = dummy::external(42)
          store &var_1 <- n0:int
          jmp node_2
          .handlers node_1

      #node_1:
          throw "Undefined Behaviour"

      #node_2:
          store &var_0 <- null:void
          n1:void = load &var_0
          ret n1

    }

    declare dummy::external(int) : int
    |}]
