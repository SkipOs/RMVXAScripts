#===========================================================================
# - Visual Novel Scene
# A script that add a custom Visual-Novel-Like Scene for RPG Maker VX Ace
#---------------------------------------------------------------------------
# - by Skip0s
# - ver 0.6 02-08-25
#---------------------------------------------------------------------------
# - USAGE -
# You can use this script by calling it on script calls.
#
#   SceneManager.call(Scene_VisualNovel)      #Call Custom Scene
#
#===========================================================================
# - GENERAL OPTIONS
# Here you can customize the script
#===========================================================================

module VNConfig
  ACTION_MENU_SIDE      = :right    # Set the side of the action menu for left or right (:left or :right)
  USE_MAP               = false     # Set if the "map" will be used in the game
  ACTION_MENU_WIDTH     = 200       # Set the custom size for action menu width
  TOP_BAR_COLUMNS       = 3         # Set the total count of the top bar columns
  HUD_HEIGHT            = 36        # Set the height of the HUD (top bar)
  DIALOGUE_BOX_HEIGHT   = 100      # Set the height of the HUD (top bar)
end

#===========================================================================
# - CUSTOM MENU OPTIONS
# Here you can set the options that appear the Action Menu
#===========================================================================

module VNConfig
  ACTION_MENU_COMMANDS = [
    { name: "Item",       symbol: :item,   scene: Scene_Item   },
#    { name: "Equipar",    symbol: :equip,  scene: Scene_Equip  },
#    { name: "Status",     symbol: :status, scene: Scene_Status },
#    { name: "Habilidades",symbol: :skill,  scene: Scene_Skill  },
    { name: "Salvar",     symbol: :save,   scene: Scene_Save   },
    { name: "Interagir",  symbol: :interact, scene: nil         },  # só para teste de texto
  ]
end
#===========================================================================
# - Window_HUD Code
# Top-Bar config
#===========================================================================

class Window_HUD < Window_Base
  def initialize
    super(0, 0, Graphics.width, VNConfig::HUD_HEIGHT)
    refresh
  end

  def refresh
    contents.clear
    # Desenha nome do mapa na primeira coluna
    column_width = Graphics.width / VNConfig::TOP_BAR_COLUMNS
    draw_text(4, 0, column_width, line_height, $game_map.display_name)
    # TODO: desenhar variáveis nas outras colunas
  end
end

#===========================================================================
# - Window_Dialogue Code
# Bottom-Bar config
#===========================================================================

class Window_Dialogue < Window_Base
  attr_reader :finished

  def initialize
    super(0, Graphics.height - VNConfig::DIALOGUE_BOX_HEIGHT, Graphics.width, VNConfig::DIALOGUE_BOX_HEIGHT)
    @text_queue = []
    @finished = true
    refresh
  end

  # Define o texto a exibir (pode conter múltiplas linhas)
  def set_text(text)
    @text_queue = text.split("\n")
    @finished = false
    refresh
  end

  def refresh
    contents.clear
    return if @finished
    draw_text_ex(4, 4, @text_queue.first)
  end

  # Avança para a próxima linha/texto
  def advance
    @text_queue.shift
    @finished = @text_queue.empty?
    refresh
  end
end

#===========================================================================
# - Window_ActionMenu Code
# The Right side menu
#===========================================================================

class Window_ActionMenu < Window_Command
  def initialize
    x = VNConfig::ACTION_MENU_SIDE == :left ? 0 : Graphics.width - VNConfig::ACTION_MENU_WIDTH
    y = VNConfig::HUD_HEIGHT
    super(x, y)                    # aceita apenas (x, y)
    self.width  = window_width
    self.height = window_height
    refresh
    self.index = 0
  end

  def window_width
    VNConfig::ACTION_MENU_WIDTH
  end

  def window_height
    Graphics.height - VNConfig::HUD_HEIGHT - VNConfig::DIALOGUE_BOX_HEIGHT
  end

  def make_command_list
    VNConfig::ACTION_MENU_COMMANDS.each { |cmd| add_command(cmd[:name], cmd[:symbol]) }
  end
end

#===========================================================================
# - Scene_VisualNovel Code
#===========================================================================
class Scene_VisualNovel < Scene_Base
  def start
    super
    create_hud
    create_dialogue
    create_action_menu
    @mode = :action
  end

  def update
    super
    case @mode
    when :action then update_action
    when :text   then update_text
    when :idle   then update_idle
    end
  end

  private

  # Creating the windows
  def create_hud
    @hud_window = Window_HUD.new
  end

  def create_dialogue
    @dialogue_window = Window_Dialogue.new
  end

  def create_action_menu
    @action_menu = Window_ActionMenu.new
    @action_menu.set_handler(:ok,     method(:on_action_ok))
    @action_menu.set_handler(:cancel, method(:on_action_cancel))
  end

  # Fluxo: ação -> texto -> idle
 def update_action
    if Input.trigger?(:C)
      @action_menu.call_ok_handler
    elsif Input.trigger?(:B)   # reativa o cancel aqui
      on_action_cancel
    end
  end

  def on_action_ok
    sym = @action_menu.current_symbol
    if sym == :interact
      # seu loop de teste
      sample = [
        "Linha 1: Você toca na porta antiga…",
        "Linha 2: Ela range ao se abrir lentamente…",
        "Linha 3: Um corredor escuro se revela à sua frente."
      ].join("\n")
      @dialogue_window.set_text(sample)
      @mode = :text
    else
      cmd = VNConfig::ACTION_MENU_COMMANDS.find { |c| c[:symbol] == sym }
      SceneManager.call(cmd[:scene]) if cmd && cmd[:scene]
    end
  end

  def on_action_cancel
    # volta ao menu de configurações
    SceneManager.call(Scene_Config)
  end

  def update_text
    if Input.trigger?(:C) || Input.trigger?(:B)
      if @dialogue_window.finished
        @mode = :idle
      else
        @dialogue_window.advance
      end
    end
  end

  def update_idle
    @mode = :action
  end
end
