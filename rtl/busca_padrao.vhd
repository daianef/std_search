--------------------------------------------------------------------------------------------------------------------------
--	Projeto: Busca Padrao
--	Autores: Daiane Fraga, Gilson Almeida
--	Data: 01/07/2013
--	Trabalho Final - Microeletronica - FACIN/PUCRS
--------------------------------------------------------------------------------------------------------------------------

-- #######################################################################################################################                 

library ieee;
	use ieee.std_logic_1164.all;

-- 
-- Entidade: interface externa do circuito (pinos de entrada e saida)
--
entity busca_padrao is
	port
	(
		Bus2IP_Clk		: in  std_logic;
		Bus2IP_Reset	: in  std_logic;
		Bus2IP_RdCE		: in  std_logic_vector(0 to 14);
		Bus2IP_WrCE		: in  std_logic_vector(0 to 14);
		Bus2IP_Data		: in  std_logic_vector(7 downto 0);
		IP2Bus_Data		: out std_logic_vector(7 downto 0);
		user_int		: out std_logic
	);
end entity busca_padrao;

--
-- Arquitetura: descricao comportamental do circuito
--
architecture busca of busca_padrao is

	----- Definicao de tipos -----
	-- Banco de registradores
	type bank is array(0 to  14) of std_logic_vector(7 downto 0);   
	-- Bloco de RAM
	type iram is array(0 to 255) of std_logic_vector(7 downto 0);
	-- Estados para a maquina de estados
	type states is 
	(
		S_REP, 
		S_PI1, 
		S_PI2, 
		S_PI3, 
		S_PI4, 
		S_PI5, 
		S_PI6, 
		S_PI7, 
		S_PI8, 
		S_PI9, 
		S_MATCH, 
		S_NEXT_PIXEL, 
		S_END
	);

	----- Constantes -----
	-- Imagem 
	constant IMG 						: iram;

	----- Sinais -----
	-- Sinais para os estados
	signal current_state, next_state	: states;
	-- Instancia do banco de registradores
	signal slv_reg						: bank;
	-- Sinais para enderecamento de pixel
	signal address, pixel				: std_logic_vector(7 downto 0);
	-- Contador de matches: quantos resultados foram encontrados
	signal matches_counter				: integer;
	-- Coordenadas X e Y
	signal addr_x, addr_y				: std_logic_vector(3 downto 0);
	-- Sinais auxiliares para coordenadas
	signal aux_addr_x, aux_addr_y		: std_logic_vector(3 downto 0);

	----- Sinais de saida -----
	-- Barramento de dados
	signal	IP2Bus_Data_s				: std_logic_vector(7 downto 0);
	-- Interrupcao do usuario
	signal	user_int_s					: std_logic;

begin

	-- Memoria ROM com uma imagem de 256 pixels (16x16)
	IMG <= 
	(
		x"40", x"00", x"24", x"9C", x"24", x"9D", x"24", x"9E", x"44", x"9D", x"24", x"FF", x"44", x"9E", x"24", x"FE",
		x"44", x"9C", x"24", x"A0", x"CC", x"4D", x"44", x"A0", x"24", x"CC", x"72", x"9C", x"BC", x"21", x"CC", x"02",
		x"24", x"9F", x"44", x"9F", x"50", x"FF", x"24", x"9F", x"BC", x"8C", x"E6", x"40", x"32", x"10", x"40", x"C6",
		x"8C", x"F8", x"00", x"00", x"00", x"00", x"8C", x"E8", x"D0", x"50", x"FF", x"BC", x"04", x"00", x"00", x"40",
		x"1C", x"44", x"A0", x"24", x"9D", x"50", x"A7", x"BC", x"02", x"00", x"24", x"9C", x"44", x"9D", x"24", x"A0",
		x"8C", x"CB", x"40", x"00", x"24", x"9C", x"24", x"9D", x"CC", x"44", x"9E", x"24", x"A0", x"CC", x"06", x"44",
		x"24", x"9E", x"8C", x"B9", x"44", x"A0", x"50", x"01", x"24", x"A0", x"70", x"0F", x"50", x"F6", x"BC", x"01",
		x"D0", x"44", x"A0", x"70", x"F0", x"50", x"10", x"24", x"A0", x"50", x"60", x"BC", x"01", x"D0", x"40", x"00",
		x"24", x"A0", x"D0", x"44", x"9C", x"70", x"0F", x"BC", x"01", x"D0", x"44", x"A1", x"54", x"A1", x"24", x"A1",
		x"BC", x"03", x"24", x"FD", x"D0", x"40", x"01", x"24", x"A1", x"8C", x"F7", x"00", x"00", x"00", x"00", x"00",
		x"00", x"9C", x"A0", x"44", x"9D", x"24", x"A0", x"CC", x"1C", x"44", x"9F", x"44", x"9F", x"50", x"A7", x"BC",
		x"02", x"8C", x"CB", x"40", x"00", x"24", x"9C", x"00", x"24", x"9C", x"F8", x"00", x"00", x"9E", x"44", x"9D",
		x"24", x"FF", x"44", x"9E", x"24", x"FE", x"CC", x"72", x"44", x"9C", x"44", x"A0", x"24", x"4D", x"44", x"A0",
		x"24", x"9C", x"24", x"9C", x"44", x"9D", x"24", x"A0", x"8C", x"F8", x"00", x"00", x"00", x"50", x"60", x"BC",
		x"24", x"9F", x"BC", x"8C", x"40", x"00", x"24", x"9C", x"40", x"00", x"24", x"9C", x"9F", x"BC", x"8C", x"E6",
		x"9D", x"50", x"A7", x"BC", x"02", x"00", x"24", x"9C", x"00", x"9C", x"A0", x"44", x"9F", x"50", x"FF", x"24"
	);

	-- Leitura da memoria ROM: endereco do pixel para analise
	pixel <= IMG(CONV_INTEGER(address));

	------------------------ Maquina de estados: logica combinacional --------------------------------
	fsm_comb: process(current_state)
	begin
		case current_state is

			when S_REP =>

				if (slv_reg(9)(0) = '1') then
					
					slv_reg(9)(0) = '0';
					next_state <= PI1;
				else
					next_state <= S_REP;
				end if;

			when S_PI1 =>

				if  (slv_reg(0) = pixel) then
					next_state <= S_PI2;
				else
					next_state <= S_NEXT_PIXEL;
				end if;

				address <= addr_y & addr_x;

			when S_PI2 => 

				if  (slv_reg(1) = pixel) then
					next_state <= S_PI3;
				else
					next_state <= S_NEXT_PIXEL;
				end if;

				address <= addr_y & (addr_x + 1);

			when S_PI3 =>

				if  (slv_reg(2) = pixel) then
					next_state <= S_PI4;
				else
					next_state <= S_NEXT_PIXEL;
				end if;

				address <= addr_y & (addr_x + 2);

			when S_PI4 => 

				if  (slv_reg(3) = pixel) then
					next_state <= S_PI5;
				else
					next_state <= S_NEXT_PIXEL;
				end if;

				address <= (addr_y + 1) & addr_x;

			when S_PI5 =>

				if  (slv_reg(4) = pixel) then
					next_state <= S_PI6;
				else
					next_state <= S_NEXT_PIXEL;
				end if;

				address <= (addr_y + 1) & (addr_x + 1);

			when S_PI6 =>

				if  (slv_reg(5) = pixel) then
					next_state <= S_PI7;
				else
					next_state <= S_NEXT_PIXEL;
				end if;

				address <= (addr_y + 1) & (addr_x + 2);

			when S_PI7 =>

				if  (slv_reg(6) = pixel) then
					next_state <= S_PI8;
				else
					next_state <= S_NEXT_PIXEL;
				end if;

				address <= (addr_y + 2) & addr_x;

			when S_PI8 =>

				if  (slv_reg(7) = pixel) then
					next_state <= S_PI9;
				else
					next_state <= S_NEXT_PIXEL;
				end if;

				address <= (addr_y + 2) & (addr_x + 1);

			when S_PI9 =>

				if  (slv_reg(8) = pixel) then
					next_state <= S_MATCH;
				else
					next_state <= S_NEXT_PIXEL;
				end if;

				address <= (addr_y + 2) & (addr_x + 2);

			when S_MATCH =>
				
				matches_counter <= matches_counter + 1;
				next_state <= S_NEXT_PIXEL;

			when S_NEXT_PIXEL =>

				addr_x <= addr_x + 1;

				if (addr_x = "1111") then
					addr_x <= (others => '0');
					addr_y <= addr_y + 1;

					if (addr_y = "1111") then
						next_state <= S_END;
					end if;
				end if;

			when S_END =>

				next_state <= S_REP;

			when others =>

				null;

		end case;
	end process fsm_comb;

	------------------------ Maquina de estados: alteracao de estados --------------------------------
	fsm_reg: process(Bus2IP_Clk, Bus2IP_Reset)
	begin
		-- Operacao na borda de subida do clock 
		if (Bus2IP_Clk'event and Bus2IP_Clk = '1') then
			-- Reset sincrono
			if (Bus2IP_Reset = '1') then
				-- Reseta indo para o primeiro estado
				current_state <= S_REP;
			else
				-- Seta estado atual
				current_state <= next_state;
			end if;
		end if;
	end process fsm_reg;
    
end busca;

-- #######################################################################################################################