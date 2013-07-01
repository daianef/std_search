--------------------------------------------------------------------------------------------------------------------------
--	Projeto: Busca Padrao
--	Autores: Daiane Fraga, Gilson Almeida
--	Data: 01/07/2013
--	Trabalho Final - Microeletronica - FACIN/PUCRS
--------------------------------------------------------------------------------------------------------------------------
-- Proposito: Realizar a busca em uma imagem internamente armazenada no circuito a partir de um padrao fornecido.
--------------------------------------------------------------------------------------------------------------------------

-- #######################################################################################################################                 

library ieee;
	use ieee.std_logic_1164.all;
	use ieee.std_logic_unsigned.all;

-- 
-- Entidade: interface externa do circuito (pinos de entrada e saida)
--
entity busca_padrao is
	port
	(
		Bus2IP_Clk	: in  std_logic;
		Bus2IP_Reset: in  std_logic;
		Bus2IP_RdCE	: in  std_logic_vector(0 to 14);
		Bus2IP_WrCE	: in  std_logic_vector(0 to 14);
		Bus2IP_Data	: in  std_logic_vector(7 downto 0);
		IP2Bus_Data	: out std_logic_vector(7 downto 0);
		user_int	: out std_logic
	);
end entity busca_padrao;

--
-- Arquitetura: descricao comportamental do circuito
--
architecture busca of busca_padrao is

	----- Definicao de tipos -----
	-- Banco de registradores
	type bank is array(0 to  14) of std_logic_vector(7 downto 0);   
	-- Bloco com a imagem
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
	-- Memoria ROM com uma imagem de 256 pixels (16x16)
	constant IMG : iram :=
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

	----- Sinais -----
	-- Sinais para os estados
	signal current_state, next_state	: states;
	-- Instancia do banco de registradores
	signal slv_reg						: bank;
	-- Sinais para enderecamento de pixel
	signal address, pixel				: std_logic_vector(7 downto 0);
	-- Contador de matches: quantos resultados foram encontrados (max. e' cerca de 25)
	signal matches_counter				: std_logic_vector(7 downto 0);
	-- Indica onde salvar o resultado (0 -> regs 11 e 12; 1 -> regs 13 e 14)
	signal next_saved_addr				: std_logic;
	-- Coordenadas X e Y
	signal addr_x, addr_y				: std_logic_vector(3 downto 0);

	----- Sinais de saida -----
	-- Barramento de dados
	signal	IP2Bus_Data_s				: std_logic_vector(7 downto 0);
	-- Interrupcao do usuario
	signal	user_int_s					: std_logic;

begin

	-- Mapeamento de pinos para tratamento interno
	IP2Bus_Data	<= IP2Bus_Data_s;
	user_int	<= user_int_s;

	-- Leitura da memoria ROM: endereco do pixel para analise
	pixel <= IMG(CONV_INTEGER(address));

	------------------------ Maquina de estados: alteracao de estado --------------------------------
	fsm_reg: process(Bus2IP_Clk, Bus2IP_Reset)
	begin
		-- Reset sincrono
		if (Bus2IP_Reset = '1') then
			-- Reseta indo para o primeiro estado
			current_state <= S_REP;
		-- Operacao na borda de subida do clock 
		elsif (Bus2IP_Clk'event and Bus2IP_Clk = '1') then
			-- Seta estado atual
			current_state <= next_state;
		end if;
	end process fsm_reg;

	------------------------ Maquina de estados: logica combinacional --------------------------------
	fsm_comb: process(Bus2IP_Clk, Bus2IP_Reset, current_state, slv_reg, pixel, addr_x, addr_y)
	begin
		case current_state is

			when S_REP =>
				if (slv_reg(9)(0) = '1') then
					next_state <= S_PI1;
				else
					next_state <= S_REP;
				end if;

			when S_PI1 =>
				if  (slv_reg(0) = pixel) then
					next_state <= S_PI2;
				else
					next_state <= S_NEXT_PIXEL;
				end if;

			when S_PI2 => 
				if  (slv_reg(1) = pixel) then
					next_state <= S_PI3;
				else
					next_state <= S_NEXT_PIXEL;
				end if;

			when S_PI3 =>
				if  (slv_reg(2) = pixel) then
					next_state <= S_PI4;
				else
					next_state <= S_NEXT_PIXEL;
				end if;

			when S_PI4 => 
				if  (slv_reg(3) = pixel) then
					next_state <= S_PI5;
				else
					next_state <= S_NEXT_PIXEL;
				end if;

			when S_PI5 =>
				if  (slv_reg(4) = pixel) then
					next_state <= S_PI6;
				else
					next_state <= S_NEXT_PIXEL;
				end if;

			when S_PI6 =>
				if  (slv_reg(5) = pixel) then
					next_state <= S_PI7;
				else
					next_state <= S_NEXT_PIXEL;
				end if;

			when S_PI7 =>
				if  (slv_reg(6) = pixel) then
					next_state <= S_PI8;
				else
					next_state <= S_NEXT_PIXEL;
				end if;

			when S_PI8 =>
				if  (slv_reg(7) = pixel) then
					next_state <= S_PI9;
				else
					next_state <= S_NEXT_PIXEL;
				end if;

			when S_PI9 =>
				if  (slv_reg(8) = pixel) then
					next_state <= S_MATCH;
				else
					next_state <= S_NEXT_PIXEL;
				end if;

			when S_MATCH =>
				next_state <= S_NEXT_PIXEL;

			when S_NEXT_PIXEL =>
				if (addr_x = "1111" and addr_y = "1110") then
					next_state <= S_END;
				else 
					next_state <= S_PI1;
				end if;

			when S_END =>
				next_state <= S_REP;

			when others =>
				null;
		end case;
	end process fsm_comb;

	data_reading: process(Bus2IP_RdCE, Bus2IP_Reset)
	begin
		if (Bus2IP_Reset = '1') then
			IP2Bus_Data_s <= (others => '0');
		end if;

		case Bus2IP_RdCE is
			-- Envia numero de matches
			when "000000000010000" =>
				IP2Bus_Data_s <= slv_reg(10);
			
			-- Primeiro match - coordenada x
			when "000000000001000" =>
				IP2Bus_Data_s <= slv_reg(11);

			-- Primeiro match - coordenada y
			when "000000000000100" =>
				IP2Bus_Data_s <= slv_reg(12);

			-- Segundo match - coordenada x
			when "000000000000010" =>
				IP2Bus_Data_s <= slv_reg(13);

			-- Segundo match - coordenada y
			when "000000000000001" =>
				IP2Bus_Data_s <= slv_reg(14);

			when others =>
				null;
		end case;
	end process data_reading;

	------------------------ Controle e registro de dados --------------------------------
	data_control: process(Bus2IP_Clk, Bus2IP_Reset)
	begin
		if (Bus2IP_Reset = '1') then
			slv_reg <= (others => (others => '0'));
			matches_counter <= (others => '0');
			user_int_s <= '0';
			next_saved_addr <= '0';

		elsif (Bus2IP_Clk'event and Bus2IP_Clk = '1') then
			case current_state is
				when S_REP =>
					-- Recebe o padrao a ser usado na busca e 
					-- armazena nos registradores de 0 a 9
					case Bus2IP_WrCE is
						when "100000000000000" =>
							slv_reg(0) <= Bus2IP_Data;

						when "010000000000000" =>
							slv_reg(1) <= Bus2IP_Data;

						when "001000000000000" =>
							slv_reg(2) <= Bus2IP_Data;

						when "000100000000000" =>
							slv_reg(3) <= Bus2IP_Data;

						when "000010000000000" =>
							slv_reg(4) <= Bus2IP_Data;

						when "000001000000000" =>
							slv_reg(5) <= Bus2IP_Data;

						when "000000100000000" =>
							slv_reg(6) <= Bus2IP_Data;

						when "000000010000000" =>
							slv_reg(7) <= Bus2IP_Data;

						when "000000001000000" =>
							slv_reg(8) <= Bus2IP_Data;

						when "000000000100000" =>
							slv_reg(9) <= Bus2IP_Data;

						when others =>
							null;

					end case;

				when S_PI1 =>
					slv_reg(9)(0) <= '0';

				when S_MATCH => 
					matches_counter <= matches_counter + 1;

					if (next_saved_addr = '0') then
						slv_reg(11) <= "0000" & addr_x;
						slv_reg(12) <= "0000" & addr_y;
						next_saved_addr <= '1';
					else
						slv_reg(13) <= "0000" & addr_x;
						slv_reg(14) <= "0000" & addr_y;
					end if;

				when S_END =>
					user_int_s <= '1';
					slv_reg(10) <= matches_counter;

				when others =>
					null;
			end case;
		end if;
	end process data_control;

	addr_control: process(current_state, Bus2IP_Reset)
	begin
		if (Bus2IP_Reset = '1') then
			address <= (others => '0');
			addr_x <= (others => '0');
			addr_y <= (others => '0');
		end if;

		case current_state is
			when S_PI1 =>
				address <= addr_y & addr_x;

			when S_PI2 => 
				address <= addr_y & (addr_x + 1);

			when S_PI3 =>
				address <= addr_y & (addr_x + 2);

			when S_PI4 => 
				address <= (addr_y + 1) & addr_x;

			when S_PI5 =>
				address <= (addr_y + 1) & (addr_x + 1);

			when S_PI6 =>
				address <= (addr_y + 1) & (addr_x + 2);

			when S_PI7 =>
				address <= (addr_y + 2) & addr_x;

			when S_PI8 =>
				address <= (addr_y + 2) & (addr_x + 1);

			when S_PI9 =>
				address <= (addr_y + 2) & (addr_x + 2);

			when S_NEXT_PIXEL =>
				addr_x <= addr_x + 1;

				if (addr_x = "1111") then
					addr_x <= (others => '0');
					addr_y <= addr_y + 1;
				end if;

			when others =>
				null;
		end case;
	end process addr_control;

end busca;

-- #######################################################################################################################
