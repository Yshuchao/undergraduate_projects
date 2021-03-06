library	ieee;
use		ieee.std_logic_1164.all;
use		ieee.std_logic_unsigned.all;
use		ieee.std_logic_arith.all;

library work;
use work.chess_objects.all;

entity vga640480 is
	 port(
			address_board		:		  out	STD_LOGIC_VECTOR(15 DOWNTO 0);
			address_piece		:		  out	STD_LOGIC_VECTOR(14 DOWNTO 0);
			address_digits		:		  out	STD_LOGIC_VECTOR(12 DOWNTO 0);
			in_pieces: in piece_matrix;
			in_state: in game_state;
			in_player: in std_logic;
			in_life_r, in_life_b: in integer range 0 to 60;
			in_score_times: in integer range 0 to 2047;
			in_has_select: in std_logic;
			in_select_x: in integer range 0 to X - 1;
			in_select_y: in integer range 0 to Y - 1;
			mousex,mousey:in std_logic_vector(9 downto 0);
			reset       :         in  STD_LOGIC;
			clk50       :		  out std_logic; 
			q_board		    :		  in STD_LOGIC_vector(8 downto 0);
			q_piece		    :		  in STD_LOGIC_vector(8 downto 0);
			q_digits		    :		  in STD_LOGIC_vector(8 downto 0);
			clk_0       :         in  STD_LOGIC; --100M����?����?��?
			hs,vs       :         out STD_LOGIC; --DD��?2??��3?��?2?D?o?
			r,g,b       :         out STD_LOGIC_vector(2 downto 0)
	  );
end vga640480;

architecture behavior of vga640480 is
	
	signal r1,g1,b1   : std_logic_vector(2 downto 0);					
	signal hs1,vs1    : std_logic;				
	signal vector_x : std_logic_vector(9 downto 0);		--X��?����
	signal vector_y : std_logic_vector(8 downto 0);		--Y��?����
	signal clk,clk25	:	 std_logic;
begin

clk50 <= clk;
 -----------------------------------------------------------------------
  process(clk_0)	--??100M��?��?D?o??t��??��
    begin
        if(clk_0'event and clk_0='1') then 
             clk <= not clk;
        end if;
 	end process;
  process(clk)
	begin
		if(clk'event and clk='1') then
			clk25 <= not clk25;
		end if;
	end process;

 -----------------------------------------------------------------------
	 process(clk25,reset)	--DD????????��y�ꡧo???��t??��?
	 begin
	  	if reset='0' then
	   		vector_x <= (others=>'0');
	  	elsif clk25'event and clk25='1' then
	   		if vector_x=799 then
	    		vector_x <= (others=>'0');
	   		else
	    		vector_x <= vector_x + 1;
	   		end if;
	  	end if;
	 end process;

  -----------------------------------------------------------------------
	 process(clk25,reset)	--3?????DD��y�ꡧo???��t??��?
	 begin
	  	if reset='0' then
	   		vector_y <= (others=>'0');
	  	elsif clk25'event and clk25='1' then
	   		if vector_x=799 then
	    		if vector_y=524 then
	     			vector_y <= (others=>'0');
	    		else
	     			vector_y <= vector_y + 1;
	    		end if;
	   		end if;
	  	end if;
	 end process;
 
  -----------------------------------------------------------------------
	 process(clk25,reset) --DD��?2?D?o?2�������ꡧ��?2??��?��96��??��??16��?
	 begin
		  if reset='0' then
		   hs1 <= '1';
		  elsif clk25'event and clk25='1' then
		   	if vector_x>=656 and vector_x<752 then
		    	hs1 <= '0';
		   	else
		    	hs1 <= '1';
		   	end if;
		  end if;
	 end process;
 
 -----------------------------------------------------------------------
	 process(clk25,reset) --3?��?2?D?o?2�������ꡧ��?2??��?��2��??��??10��?
	 begin
	  	if reset='0' then
	   		vs1 <= '1';
	  	elsif clk25'event and clk25='1' then
	   		if vector_y>=490 and vector_y<492 then
	    		vs1 <= '0';
	   		else
	    		vs1 <= '1';
	   		end if;
	  	end if;
	 end process;
 -----------------------------------------------------------------------
	 process(clk25,reset) --DD��?2?D?o?��?3?
	 begin
	  	if reset='0' then
	   		hs <= '0';
	  	elsif clk25'event and clk25='1' then
	   		hs <=  hs1;
	  	end if;
	 end process;

 -----------------------------------------------------------------------
	 process(clk25,reset) --3?��?2?D?o?��?3?
	 begin
	  	if reset='0' then
	   		vs <= '0';
	  	elsif clk25'event and clk25='1' then
	   		vs <=  vs1;
	  	end if;
	 end process;
	
 -----------------------------------------------------------------------	
	process(reset,clk25,vector_x,vector_y) -- XY��?����?��??????
	variable dx: integer range 0 to 164;
	variable dy: integer range 0 to 82;
	variable s0,s1,s2,s3: integer range 0 to 9;
	begin  
		if reset='0' then
			        r1  <= "000";
					g1	<= "000";
					b1	<= "000";	
		elsif(clk25'event and clk25='1')then
			if vector_x>144 and vector_y>145 and vector_x<490 and vector_y<335 then--if vector_x<352 and vector_y<190 then--the board
				address_board <= conv_std_logic_vector((conv_integer(vector_x)-144)*190+(conv_integer(vector_y-145)),16);
				r1  <= q_board(8 downto 6);
				g1	<= q_board(5 downto 3);
				b1	<= q_board(2 downto 0);
			else
				r1  <= "000";
				g1	<= "000";
				b1	<= "000";
			end if;
			
			for i in 0 to X-1 loop--the pieces
				for j in 0 to Y-1 loop
					if in_pieces(j)(i).exist='1' then
						if vector_x<(j*38+164+37+j/4) and vector_x>(j*38+164+j/4) and vector_y<(i*38+164+37) and vector_y>(i*38+164) then
							if in_pieces(j)(i).opened='0' then--piece not opened
								dx:=0;
								dy:=0;
							else--piece opened
								if in_pieces(j)(i).color='0' then--red
									case in_pieces(j)(i).piece_type is
										when 0 => dx:=148;dy:=37;
										when 1 => dx:=111;dy:=37;
										when 2 => dx:=0;dy:=74;
										when 3 => dx:=148;dy:=74;
										when 4 => dx:=74;dy:=74;
										when 5 => dx:=37;dy:=74;
										when 6 => dx:=111;dy:=74;
									end case;
								else--black
									case in_pieces(j)(i).piece_type is
										when 0 => dx:=37;dy:=0;
										when 1 => dx:=74;dy:=0;
										when 2 => dx:=111;dy:=0;
										when 3 => dx:=74;dy:=37;
										when 4 => dx:=0;dy:=37;
										when 5 => dx:=148;dy:=0;
										when 6 => dx:=37;dy:=37;
									end case;
								end if;
							end if;
							address_piece<=conv_std_logic_vector(((conv_integer(vector_x)-164-j-j/4)rem 37+dx)*111+(conv_integer(vector_y)-164-i) rem 37 +dy,15);
							r1  <= q_piece(8 downto 6);
							g1	<= q_piece(5 downto 3);
							b1	<= q_piece(2 downto 0);
							if q_piece="111111111" and not(in_has_select='1' and i=in_select_x and j=in_select_y) then--and in_has_select='0' and ((not (i=in_select_x)) or (not (j=in_select_y)))
								r1  <= q_board(8 downto 6);
								g1	<= q_board(5 downto 3);
								b1	<= q_board(2 downto 0);
							end if;
						end if;
					end if;
				end loop;
			end loop;
			
			if vector_x<640 and vector_y<480 then--mouse
				if conv_integer(mousex)<conv_integer(vector_x) and conv_integer(mousey)<conv_integer(vector_y) and conv_integer(mousey)+10>conv_integer(vector_y) and conv_integer(mousex)+10>vector_x then
					r1  <= "111";
					g1	<= "111";
					b1	<= "111";
				end if;
			end if;
			
			if vector_x>144 and vector_x<264 and vector_y>130 and vector_y<135 then--red hp
				if vector_x-144<in_life_r*2 then
					r1  <= "111";
					g1	<= "010";
					b1	<= "010";
				end if;
			end if;
			
			if vector_x>144 and vector_x<264 and vector_y>340 and vector_y<345 then--black hp
				if vector_x-144<in_life_b*2 then
					r1  <= "010";
					g1	<= "010";
					b1	<= "111";
				end if;
			end if;
			

			s3:=in_score_times/1000;
			s2:=in_score_times/100-s3*10;
			s1:=in_score_times/10-s2*10;
			s0:=in_score_times mod 10;
			if vector_x>347 and vector_x<374 and vector_y>100 and vector_y<128 then--score times			
				address_digits<=conv_std_logic_vector((conv_integer(vector_x)-350+ (s3 mod 5)*24)*54+(conv_integer(vector_y)-100),13);
				r1<=q_digits(8 downto 6);
				g1<=q_digits(5 downto 3);
				b1<=q_digits(2 downto 0);
			end if;
			if vector_x>382 and vector_x<409 and vector_y>100 and vector_y<128 then			
				address_digits<=conv_std_logic_vector((conv_integer(vector_x)-385+ (s2 mod 5)*24)*54+(conv_integer(vector_y)-100 + (s2/5)*27),13);
				r1<=q_digits(8 downto 6);
				g1<=q_digits(5 downto 3);
				b1<=q_digits(2 downto 0);
			end if;
			if vector_x>417 and vector_x<444 and vector_y>100 and vector_y<128 then--score times			
				address_digits<=conv_std_logic_vector((conv_integer(vector_x)-420+ (s1 mod 5)*24)*54+(conv_integer(vector_y)-100 + (s1/5)*27),13);
				r1<=q_digits(8 downto 6);
				g1<=q_digits(5 downto 3);
				b1<=q_digits(2 downto 0);
			end if;
			if vector_x>452 and vector_x<479 and vector_y>100 and vector_y<128 then--score times			
				address_digits<=conv_std_logic_vector((conv_integer(vector_x)-455+ (s0 mod 5)*24)*54+(conv_integer(vector_y)-100 + (s0/5)*27),13);
				r1<=q_digits(8 downto 6);
				g1<=q_digits(5 downto 3);
				b1<=q_digits(2 downto 0);
			end if;
			
			if vector_x>134 and vector_x<144 and vector_y>235 and vector_y<245 and ((conv_integer(vector_x)-139)*(conv_integer(vector_x)-139)+(conv_integer(vector_y)-240)*(conv_integer(vector_y)-240))<25 then--player
				if in_player='0' or in_state=RED_WIN then
					r1  <= "111";
					g1	<= "000";
					b1	<= "000";
				elsif in_player='1' or in_state=BLACK_WIN then
					r1  <= "000";
					g1	<= "000";
					b1	<= "111";
				end if;
			end if;
			
		end if;		 
	    end process;	

	-----------------------------------------------------------------------
	process (hs1, vs1, r1, g1, b1)	--��?2����?3?
	begin
		if hs1 = '1' and vs1 = '1' and vector_x<640 and vector_y<480 then
			r	<= r1;
			g	<= g1;
			b	<= b1;
		else
			r	<= (others => '0');
			g	<= (others => '0');
			b	<= (others => '0');
		end if;
	end process;

end behavior;
