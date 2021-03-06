library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all; 

library work;
use work.chess_objects.all;

entity logic is 
  port (
    clock, reset: in std_logic;
    is_click: in std_logic;
    click_x: in integer range 0 to X - 1;
    click_y: in integer range 0 to Y - 1;
    out_pieces: out piece_matrix;
    out_state: out game_state;
    out_has_select: out std_logic;
    out_select_x: out integer range 0 to X - 1;
    out_select_y: out integer range 0 to Y - 1;
    out_player: out std_logic;
    out_life_r, out_life_b: out integer range 0 to 60;
    out_score: out integer range 1 to 2048
  );
end logic;

architecture arch of logic is
  signal clk_1k: std_logic := '0';
  signal div_clk_1k: integer range 0 to 99999 := 0; -- detect every 0.001s
  signal react_cnt: integer range 1 to 300 := 300;  -- react every 0.3s, will also be used to determine which piece to reset
  type new_board_t is array(0 to X * Y - 1) of piece;
  signal new_board: new_board_t;
  signal state: game_state;
  signal old_click_x: integer range 0 to X - 1;
  signal old_click_y: integer range 0 to Y - 1;
  signal has_old_click: std_logic := '0';
  signal cur_player: std_logic := '0';
  signal inner_pieces: piece_matrix;
  
  signal seed: unsigned(31 downto 0) := "00000001001001011110010110010001"; -- random number generator, seed = 19260817
  signal life_r, life_b: integer range 0 to 60;
  signal combo_cnt_r: integer range 0 to 15 := 0;
  signal combo_cnt_b: integer range 0 to 15 := 0;
  signal score_times: integer range 1 to 16 := 1;
  signal score: integer range 1 to 2048 := 1;
  -- it seems that before decalring a constant
  -- it is required to decalre its type first
  type init_piece_cnt_t is array(0 to 6) of integer range 0 to 4;
  -- since the for loop is [], the count should be actual count - 1
  constant init_piece_cnt: init_piece_cnt_t := (0, 1, 1, 1, 1, 1, 4);
  type piece_life_t is array(0 to 6) of integer range 2 to 30;
  constant piece_life: piece_life_t := (30, 10, 5, 5, 5, 5, 2);
  
  function max(x, y: integer) return integer is 
  begin
    if x < y then
      return y;
    else 
      return x;
    end if;
  end max;

  function min(x, y: integer) return integer is 
  begin
    if x < y then
      return x;
    else 
      return y;
    end if;
  end min;

  -- add board is to make this function `pure`, as ghdl warns me
  -- only consider whether location is ok, not consider the type of eaten piece
  function valid_eat(board: piece_matrix;
                     ty: integer range 0 to 6;
                     ox, nx: integer range 0 to X - 1;
                     oy, ny: integer range 0 to Y - 1) return boolean is
    variable block_cnt: integer range 0 to Y - 2;
    variable lb: integer range 0 to Y - 1;
    variable ub: integer range 0 to Y - 1;
  begin
    if ty = 5 then
      block_cnt := 0;
      if ox = nx then
        lb := min(oy, ny);
        ub := max(oy, ny);
        for i in 0 to Y - 1 loop
          if lb < i and i < ub and board(i)(nx).exist = '1' then
            block_cnt := block_cnt + 1;
          end if;
        end loop; 
        return block_cnt = 1;
      elsif oy = ny then
        lb := min(ox, nx);
        ub := max(ox, nx);
        for i in 0 to X - 1 loop
          if lb < i and i < ub and board(ny)(i).exist = '1' then
            block_cnt := block_cnt + 1;
          end if;
        end loop; 
        return block_cnt = 1;
      else 
        return false;   
      end if;
    else 
      -- avoid under/overflow...
      return (ox = nx and ((oy /= 0 and oy - 1 = ny) or (oy /= Y - 1 and oy + 1 = ny))) or 
             (oy = ny and ((ox /= 0 and ox - 1 = nx) or (ox /= X - 1 and ox + 1 = nx)));
    end if;
  end valid_eat;

  function valid_move(board: piece_matrix;
                      ty: integer range 0 to 6;
                      ox, nx: integer range 0 to X - 1;
                      oy, ny: integer range 0 to Y - 1) return boolean is
  begin
    if ty = 5 then -- p cannot move
      return false;
    else
      return valid_eat(board, ty, ox, nx, oy, ny);
    end if;
  end valid_move;

begin
  out_pieces <= inner_pieces;
  out_life_r <= life_r;
  out_life_b <= life_b;
  out_player <= cur_player;
  out_score <= score;
  out_state <= state;
  
  handle_clk : process(clock)
  begin
    if rising_edge(clock) then
      if div_clk_1k = 99999 then
        div_clk_1k <= 0;
        clk_1k <= '1';
      else 
        div_clk_1k <= div_clk_1k + 1;
        clk_1k <= '0';
      end if;
    end if;
  end process; -- handle_clk

  handle_reset_click : process(clk_1k)
    -- for handle reset
    variable tmp_piece: piece;
    variable cur: integer range 0 to X * Y;
    variable rnd: integer range 0 to X * Y - 1;
    variable loc_seed: unsigned(31 downto 0);
    -- for handle click
    variable loc_ox, loc_x: integer range 0 to X - 1;
    variable loc_oy, loc_y: integer range 0 to Y - 1;
    variable loc_op, loc_p: piece;
    variable eat_ok: boolean;
    -- for handle reduce life
    variable loc_life_r, loc_life_b: integer range 0 to 60;
    variable which_to_reset: integer range 1 to 300;
  begin
    -- report "enter process";
    if rising_edge(clk_1k) then
      -- report "rising_edge(reset)";
      if react_cnt /= 300 then
        react_cnt <= react_cnt + 1;
      end if;
      if reset = '0' then
        which_to_reset := react_cnt;
        if react_cnt = 300 then -- do first step of reset
          react_cnt <= 1;
          cur := 0;
          for color in std_logic range '0' to '1' loop
            for i in 0 to 6 loop
              for j in 0 to init_piece_cnt(i) loop 
                --                (piece_type, color, opened, exist)
                new_board(cur) <= (i, color, '0', '1'); 
                cur := cur + 1;
              end loop;
            end loop;
          end loop;
          -- should reset all internal states here
          state <= PLAYING;
          cur_player <= '0';
          has_old_click <= '0';
          life_r <= 60;
          life_b <= 60;
          combo_cnt_r <= 0;
          combo_cnt_b <= 0;
          score_times <= 1;
          score <= 1;
          out_has_select <= '0';
        else
          if 1 <= which_to_reset and which_to_reset <= X * Y - 1 then -- do every step of reset in one cycle
            loc_seed := seed;
            loc_seed := loc_seed xor shift_left(loc_seed, 13);
            loc_seed := loc_seed xor shift_right(loc_seed, 17);
            loc_seed := loc_seed xor shift_left(loc_seed, 5);
            rnd := to_integer((loc_seed(30 downto 0))) mod (which_to_reset + 1); -- omit high bit
            -- swap
            tmp_piece := new_board(rnd);
            new_board(rnd) <= new_board(which_to_reset);
            new_board(which_to_reset) <= tmp_piece;
            seed <= loc_seed;
          elsif which_to_reset = X * Y then
            for i in 0 to Y - 1 loop
              for j in 0 to X - 1 loop
                inner_pieces(i)(j) <= new_board(i * X + j);
              end loop;
            end loop;
            inner_pieces(1)(1).opened <= '1';
            inner_pieces(3)(0).opened <= '1';
            inner_pieces(4)(3).opened <= '1';
            inner_pieces(6)(2).opened <= '1';
          end if;
        end if;
      elsif is_click = '1' then
        if react_cnt = 300 then
          react_cnt <= 1;
          loc_ox := old_click_x;
          loc_oy := old_click_y;
          loc_x := click_x;
          loc_y := click_y;
          loc_op := inner_pieces(loc_oy)(loc_ox);
          loc_p := inner_pieces(loc_y)(loc_x);
          out_has_select <= '0';
          
          if state = PLAYING then
            if has_old_click = '0' then
              if loc_p.exist = '1' then
                if loc_p.opened = '0' then -- do flip
                  inner_pieces(loc_y)(loc_x).opened <= '1';
                  cur_player <= not cur_player; 
                elsif loc_p.color = cur_player then -- do select
                  has_old_click <= '1';
                  old_click_x <= loc_x;
                  old_click_y <= loc_y;
                  out_has_select <= '1';
                  out_select_x <= loc_x;
                  out_select_y <= loc_y;               
                end if;
              end if;
            else
              has_old_click <= '0';
              -- the 'loc_p.colot = cur_player' in select section already guarantee only move self piece
              -- only move a exist & opened & self piece
              if loc_op.exist = '1' and loc_op.opened = '1' then
                if loc_p.exist = '1' then -- eat
                  -- valid_eat only judges location, need to compare types below
                  if valid_eat(inner_pieces, loc_op.piece_type, loc_ox, loc_x, loc_oy, loc_y) then 
                    eat_ok := false;
                    if loc_op.piece_type = 5 then -- p
                      -- if the piece is closed or is others', eat it
                      if loc_p.opened = '0' or loc_p.color = not cur_player then 
                        eat_ok := true;
                      end if;
                    elsif loc_op.piece_type = 6 then -- b
                      -- eat opened & others' & (b or S)
                      if loc_p.opened = '1' and loc_p.color = not cur_player and (loc_p.piece_type = 0 or loc_p.piece_type = 6) then
                        eat_ok := true;
                      end if;
                    else -- others
                      -- eat opened & others' & (p.type >= op.type)
                      if loc_p.opened = '1' and loc_p.color = not cur_player and loc_op.piece_type <= loc_p.piece_type  then
                        eat_ok := true;
                      end if;
                    end if;
                    if eat_ok then 
                      inner_pieces(loc_y)(loc_x) <= loc_op;
                      inner_pieces(loc_oy)(loc_ox).exist <= '0';
                      cur_player <= not cur_player;
                      -- handle reduce life, loc_p is eaten
                      loc_life_r := life_r;
                      loc_life_b := life_b;
                      score <= score + piece_life(loc_p.piece_type) * score_times;
                      if loc_p.color = '0' then
                        if loc_op.color = '1' then -- black eat red
                          combo_cnt_b <= combo_cnt_b + 1;
                          if combo_cnt_b >= 2 then -- old >= 2 -> new >= 3
                            score_times <= score_times + 1;
                          end if;
                        else -- red eat red
                          combo_cnt_r <= 0;
                        end if;
                        loc_life_r := max(0, loc_life_r - piece_life(loc_p.piece_type));
                        life_r <= loc_life_r;
                        if loc_life_r = 0 then
                          state <= BLACK_WIN;
                        end if;
                      else 
                        if loc_op.color = '1' then -- black eat black
                          combo_cnt_b <= 0;
                        else -- red eat black
                          combo_cnt_r <= combo_cnt_r + 1;
                          if combo_cnt_r >= 2 then -- old >= 2 -> new >= 3
                            score_times <= score_times + 1;
                          end if;
                        end if;
                        loc_life_b := max(0, loc_life_b - piece_life(loc_p.piece_type));
                        life_b <= loc_life_b;
                        if loc_life_b = 0 then
                          state <= RED_WIN;
                        end if;
                      end if;
                    end if;
                  end if;
                else -- move
                  if valid_move(inner_pieces, loc_op.piece_type, loc_ox, loc_x, loc_oy, loc_y) then
                    inner_pieces(loc_y)(loc_x) <= loc_op;
                    inner_pieces(loc_oy)(loc_ox).exist <= '0';
                    cur_player <= not cur_player;
                  end if;
                end if;
              end if;
            end if;  
          end if;
        end if;
      end if;
    end if;
  end process; -- handle_reset_click
end arch;
