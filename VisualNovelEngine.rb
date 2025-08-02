#===========================================================================
# - Visual Novel Scene
# A script that add a custom Visual-Novel-Like Scene for RPG Maker VX Ace
#===========================================================================
# - by Skip0s
# - ver 0.1 02-08-25
#===========================================================================
# - USAGE -
# You can use this script by calling it on script calls.
#
#   SceneManager.call(Scene_VisualNovel)      #Call Custom Scene
#===========================================================================


#===========================================================================
# - CUSTOM MENU OPTIONS
# Here you can set the options that appear the Action Menu
#===========================================================================

module VNConfig
  ACTION_MENU_COMMANDS = [
    { name: "Item",       symbol: :item,   scene: Scene_Item   },
    { name: "Equipar",    symbol: :equip,  scene: Scene_Equip  },
    { name: "Status",     symbol: :status, scene: Scene_Status },
    { name: "Habilidades",symbol: :skill,  scene: Scene_Skill  },    
    { name: "Salvar",     symbol: :save,   scene: Scene_Save   },
  ]
end

#===========================================================================
# - Window_ActionMenu Code
# The Right side menu 
#===========================================================================

class Window_ActionMenu < Window_Command
  # x, y: posição; não precisa width/height aqui
  def initialize(x, y, width = 200)
    @window_width = width
    super(x, y)
    select(0)
    activate
  end

  # Largura fixa
  def window_width
    @window_width
  end

  # Altura exata para item_max linhas
  def window_height
    fitting_height(item_max)
  end

  # Mostrar todas as linhas de uma vez, sem scroll
  def visible_line_number
    item_max
  end

  # Puxa sempre da config
  def make_command_list
    VNConfig::ACTION_MENU_COMMANDS.each do |cmd|
      add_command(cmd[:name], cmd[:symbol], true)
    end
  end
end


#===========================================================================
# - Window_Dialogue Code
# Bottom-Bar config
#===========================================================================

class Window_Dialogue < Window_Base
  def initialize(x, y, width, lines = 4)
    super(x, y, width, fitting_height(lines))
    @full_text     = ""
    @typed_text    = ""
    @char_index    = 0
    @text_complete = true
  end

  def show_text(text)
    contents.clear
    @full_text     = convert_escape_characters(text.to_s)
    @typed_text    = ""
    @char_index    = 0
    @text_complete = false
  end

  def update
    super
    return if @text_complete || !typing_enabled?
    @frame ||= 0; @frame += 1
    if @frame % 2 == 0
      @typed_text << @full_text[@char_index]
      contents.clear
      draw_text_ex(0, 0, @typed_text)
      @char_index += 1
      if @char_index >= @full_text.size
        @text_complete = true
      end
    end
  end

  def finish_typing
    return if @text_complete
    @typed_text = @full_text.dup
    contents.clear
    draw_text_ex(0, 0, @typed_text)
    @text_complete = true
  end

  def typing?
    !@text_complete
  end

  private

  def typing_enabled?
    Cirno::Persistence.read_general_setting("Enable Typing Effect") != "false"
  end
end


#===========================================================================
# - Window_HUD Code
# Top-Bar config
#===========================================================================

class Window_HUD < Window_Base
  # x, y, width em pixels; lines = número de linhas de texto
  def initialize(x, y, width, lines = 1)
    # fitting_height(lines) calcula altura necessária para 'lines' linhas
    super(x, y, width, fitting_height(lines))
    @last_values = {}
    refresh
  end

  def refresh
    contents.clear
    # Exemplo: mostrar três valores em colunas
    vals = [
      ["Gold", $game_party.gold],
      ["Var1", $game_variables[1]],
      ["Var2", $game_variables[2]]
    ]
    cols = vals.size
    col_w = contents.width / cols
    vals.each_with_index do |(label, val), i|
      draw_text(col_w*i, 0, col_w-4, line_height, "#{label}: #{val}", 0)
    end
  end

  def update
    super
    current = { g: $game_party.gold, v1: $game_variables[1], v2: $game_variables[2] }
    if current != @last_values
      @last_values = current
      refresh
    end
  end
end


#===========================================================================
# - Scene_VisualNovel Code
#===========================================================================

class Scene_VisualNovel < Scene_Base
  # constantes de layout
  RESIZE_WIDTH     = 704
  RESIZE_HEIGHT    = 384
  DIALOGUE_LINES   = 4
  HUD_LINES        = 1

  def start
    super
    create_hud
    create_dialogue
    create_action_menu
  end

  def create_hud
    @hud = Window_HUD.new(0, 0, RESIZE_WIDTH, HUD_LINES)
  end

  def create_dialogue
    dlg_h = Window_Base.new(0, 0, 0, 0).fitting_height(DIALOGUE_LINES)
    @dialogue = Window_Dialogue.new(0, RESIZE_HEIGHT - dlg_h, RESIZE_WIDTH, DIALOGUE_LINES)
  end

  def create_action_menu
    menu_x = RESIZE_WIDTH - Window_ActionMenu.new(0,0).window_width
    @action = Window_ActionMenu.new(menu_x, @hud.height)
    # associa handlers
    VNConfig::ACTION_MENU_COMMANDS.each do |cmd|
      @action.set_handler(cmd[:symbol], proc { SceneManager.call(cmd[:scene]) })
    end
    @action.set_handler(:cancel, method(:on_action_cancel))
  end

  def update
    super
    # ESC (27) abre Config
    if Input.trigger?(:B) && Input.recent_triggered == 27
      Sound.play_cancel
      SceneManager.call(Scene_Config)
      return
    end

    # C (67) abre Save
    if Input.trigger?(:C) && Input.recent_triggered == 67
      Sound.play_ok
      SceneManager.call(Scene_Save)
      return
    end

    # Próxima/Confirm (Z, Enter, Space)
    if Input.trigger?(:C)
      if @dialogue.typing?
        @dialogue.finish_typing
      else
        @action.activate
      end
    end

    # Voltar/X (88)
    if Input.trigger?(:B) && Input.recent_triggered == 88
      Sound.play_cancel
      on_action_cancel
      return
    end

    @hud.update
    @dialogue.update
    @action.update
  end

  def on_action_cancel
    @action.activate
  end

  def terminate
    super
    [@hud, @dialogue, @action].each(&:dispose)
  end
end
