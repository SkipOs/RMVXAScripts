#=============================================================================
# Visual Novel System — VN + RPG Overlay (VX Ace / RGSS3)
#-----------------------------------------------------------------------------
# Author: Skip0s (expanded & refactored)
# Version: 1.0 — 2025-08-13
#-----------------------------------------------------------------------------
# USAGE (Event > Script Call):
#   SceneManager.call(Scene_VN)            # Start VN mode (live map logic, no tilemap)
#   SceneManager.call(Scene_VNOverlay)     # Show VN HUD as an overlay over the map
#   VN.start_overlay                       # Shortcut to open overlay (only if MODE = :overlay_rpg)
#
# OPTIONAL HELPERS (Event > Script Call):
#   VN.store_location(:tag)                # Save current map/x/y/direction under a tag
#   VN.load_location(:tag)                 # Reserve transfer to a previously stored tag
#   VN.remember_area("text")               # Save textual description for current tile
#   VN.describe_area                       # => Description for current tile (or nil)
#   VN.set_area_desc(key, "text")          # Save desc for an explicit key ("map@x,y")
#   VN.get_area_key                        # => "<map_id>@<x>,<y>"
#
# RUNTIME TOGGLES (Script Call):
#   VN.debug_map = true/false              # Show live map under pictures in VN mode
#   VN.enable_move(true/false)             # Show/Hide "Andar" in VN mode
#   VN.hide_hud(true/false)                # Hide/Show VN HUD/menus
#   VN.lock_dir(:up/:down/:left/:right, true/false)  # Lock/unlock a direction
#   # All of the above are stored internally (no Game Switch IDs required).
#
# NOTES:
# - Show Text / Choices / Battle / Transfer work natively inside VN/Overlay.
# - Player movement in VN happens only via the "Andar" command (no arrow keys).
# - The map keeps updating under the hood. In VN mode you can toggle a debug
#   flag to reveal the tilemap/characters underneath the pictures.
#=============================================================================

#=============================================================================
# == EDITABLE REGION ==========================================================
# Anything in this block is safe to tweak for your project.
#=============================================================================
module VNConfig
  # Project-wide mode (fixed; you won't toggle during gameplay): :vn or :overlay_rpg
  MODE = :vn  # :vn  or  :overlay_rpg

  # Optional: auto-enter VN on first map. Disabled by default to avoid
  # conflicts with other engines. If you enable, do so only after testing.
  AUTO_BOOT_VN = false

  # --- Defaults for INTERNAL FLAGS (no game switches needed) -----------------
  DEBUG_DEFAULT       = false   # Initial state for VN.debug_map
  MOVE_ENABLED_DEFAULT= true   # Initial state for "Andar" visibility in VN
  HUD_HIDDEN_DEFAULT  = false   # Initial state for VN HUD visibility
  DIR_LOCK_DEFAULTS   = {       # Initial per-direction locks
    up: false, down: false, left: false, right: false
  }

  # Battle transition when Cmd 301 starts a battle from events
  BATTLE_FADE_TYPE = :black   # :black, :white, :none
  # Optional custom transition Proc: -> { ... }
  BATTLE_TRANSITION = nil

  # UI labels (keep in Portuguese if you prefer)
  LABELS = {
    interact: "Interagir",
    move:     "Andar",
    exit:     "Sair"
  }

  # Dialogue window placement/size (tweak to your UI)
  MESSAGE_WINDOW_OPTS = {
    x:  0,
    y:  Graphics.height - 160,
    w:  Graphics.width,
    h:  160,
    opacity: 255
  }

  # Top HUD (always visible unless HUD hidden)
  SHOW_TOP_HUD = true
  TOP_HUD_HEIGHT = 48

  # Dialogue bar (visible even when there's no message)
  SHOW_DIALOGUE_BAR = true

  #=== Menu Layout ============================================================
  # Place the menus right under the TOP HUD and fill the space until the
  # dialogue bar. Choose which side to anchor.
  #---------------------------------------------------------------------------
  MENU_SIDE         = :left   # :left or :right
  ACTION_MENU_WIDTH = 240
  MOVE_MENU_WIDTH   = 200
  MENU_GAP          = 8

  # Helper: compute menu rectangles dynamically from current Graphics size.
  def self.menu_layout
    top    = SHOW_TOP_HUD ? TOP_HUD_HEIGHT : 0
    bottom = SHOW_DIALOGUE_BAR ? MESSAGE_WINDOW_OPTS[:h] : 0
    y      = top
    h      = Graphics.height - top - bottom
    ax     = (MENU_SIDE == :left) ? 0 : (Graphics.width - ACTION_MENU_WIDTH)
    mx     = if MENU_SIDE == :left
               ax + ACTION_MENU_WIDTH + MENU_GAP
             else
               ax - MOVE_MENU_WIDTH - MENU_GAP
             end
    { action: Rect.new(ax, y, ACTION_MENU_WIDTH, h),
      move:   Rect.new(mx, y, MOVE_MENU_WIDTH,   h) }
  end
  def self.action_menu_rect; menu_layout[:action]; end
  def self.move_menu_rect;   menu_layout[:move];   end

  #=== Action Menu Schema (easy to edit) =====================================
  # You can freely add/remove/reorder items here. Supported keys:
  # :label  => String shown in the menu
  # :symbol => Command symbol for handlers
  # :show   => :always | :vn_only | :overlay_only
  # :enabled_if => Proc evaluated at runtime to enable/disable
  # :open_scene => Scene class to call (optional)
  ACTION_MENU_ITEMS = [
    { label: LABELS[:interact], symbol: :interact, show: :always },
    { label: LABELS[:move],     symbol: :move,     show: :vn_only,
      enabled_if: -> { VN.move_enabled? } },

    # === Built-in menus (vínculo com cenas existentes) ======================
    # Use símbolos ou classes. Se usar símbolo/string, o script resolve para a classe.
    { label: "Item",   symbol: :item,  show: :always, open_scene: :Scene_Item },
    { label: "Salvar", symbol: :save,  show: :always, open_scene: :Scene_Save,
      enabled_if: -> { !$game_system || !$game_system.respond_to?(:save_disabled?) ? true : !$game_system.save_disabled? } },
    # Exemplos adicionais (descomente se quiser):
    # { label: "Habilidades", symbol: :skill,  show: :always, open_scene: :Scene_Skill },
    # { label: "Equipar",     symbol: :equip,  show: :always, open_scene: :Scene_Equip },
    # { label: "Status",      symbol: :status, show: :always, open_scene: :Scene_Status },
    # { label: "Opções",      symbol: :config, show: :always, open_scene: :Scene_Config }, # do script Cirno

    # === Custom callback (ação própria, sem trocar de cena) =================
    # { label: "Custom", symbol: :custom, show: :always, on_select: -> { p :custom_clicked } },
  ]

  # Debug helpers
  DEBUG_FORCE_THROUGH = true     # when debug_map is ON, ignore passability
  DEBUG_PLAYER_MARKER = true     # show a red marker on player position
end
# == EDITABLE REGION END ======================================================

#=============================================================================
# -- DANGER ZONE --------------------------------------------------------------
# WARNING: Do not edit below unless you know exactly what you're doing.
# You may break event flow, message routing, or battle/transfer handling.
#=============================================================================

#=============================================================================
# -- DANGER ZONE --------------------------------------------------------------
# WARNING: Do not edit below unless you know exactly what you're doing.
# You may break event flow, message routing, or battle/transfer handling.
#=============================================================================

#-----------------------------------------------------------------------------
# Game_System patch — persistent buckets for VN helpers and internal flags
#-----------------------------------------------------------------------------
class Game_System
  attr_accessor :vn_locations      # { Symbol => {map_id:, x:, y:, d:} }
  attr_accessor :vn_area_descs     # { "map@x,y" => String }
  attr_accessor :vn_debug_map      # Boolean
  attr_accessor :vn_move_enabled   # Boolean
  attr_accessor :vn_hud_hidden     # Boolean
  attr_accessor :vn_dir_lock       # { up:, down:, left:, right: } => Boolean

  alias skip0s_vn_init initialize
  def initialize
    skip0s_vn_init
    @vn_locations   ||= {}
    @vn_area_descs  ||= {}
    @vn_debug_map     = VNConfig::DEBUG_DEFAULT
    @vn_move_enabled  = VNConfig::MOVE_ENABLED_DEFAULT
    @vn_hud_hidden    = VNConfig::HUD_HIDDEN_DEFAULT
    @vn_dir_lock      = VNConfig::DIR_LOCK_DEFAULTS.dup
  end
end

#-----------------------------------------------------------------------------
# VN utilities — mode checks, internal flags, helper API (store/load/describe)
#-----------------------------------------------------------------------------
module VN
  module_function

  # -- Mode flags -------------------------------------------------------------
  def vn_mode?;      VNConfig::MODE == :vn; end
  def overlay_mode?; VNConfig::MODE == :overlay_rpg; end

  # -- Internal toggles (no game switches) -----------------------------------
  def debug_map;        $game_system.vn_debug_map; end
  def debug_map=(v);    $game_system.vn_debug_map = !!v; end

  def enable_move(v=true); $game_system.vn_move_enabled = !!v; end
  def move_enabled?;       $game_system.vn_move_enabled; end

  def hide_hud(v=true); $game_system.vn_hud_hidden = !!v; end
  def hud_hidden?;     $game_system.vn_hud_hidden; end

  def lock_dir(sym, v=true)
    ensure_dir_hash
    $game_system.vn_dir_lock[sym] = !!v if [:up,:down,:left,:right].include?(sym)
  end

  def dir_blocked?(sym)
    ensure_dir_hash
    !!$game_system.vn_dir_lock[sym]
  end

  def ensure_dir_hash
    $game_system.vn_dir_lock ||= VNConfig::DIR_LOCK_DEFAULTS.dup
  end

  # -- Overlay entry ----------------------------------------------------------
  # Open overlay scene from events (only meaningful if MODE = :overlay_rpg)
  def start_overlay
    return unless overlay_mode?
    SceneManager.call(Scene_VNOverlay)
  end

  # -- OPTIONAL HELPERS: location registry -----------------------------------
  def store_location(tag)
    t = tag.to_sym
    ($game_system.vn_locations ||= {})[t] = {
      map_id: $game_map.map_id,
      x:      $game_player.x,
      y:      $game_player.y,
      d:      $game_player.direction
    }
  end

  def load_location(tag)
    data = ($game_system.vn_locations || {})[tag.to_sym]
    return false unless data
    begin
      $game_player.reserve_transfer(data[:map_id], data[:x], data[:y], data[:d])
    rescue
      $game_player.reserve_transfer(data[:map_id], data[:x], data[:y])
    end
    true
  end

  # -- OPTIONAL HELPERS: per-tile area descriptions --------------------------
  def get_area_key
    "#{ $game_map.map_id }@#{ $game_player.x },#{ $game_player.y }"
  end

  def set_area_desc(key, text)
    ($game_system.vn_area_descs ||= {})[key] = text
  end

  def remember_area(text)
    set_area_desc(get_area_key, text)
  end

  def describe_area
    ($game_system.vn_area_descs || {})[get_area_key]
  end
end

#-----------------------------------------------------------------------------
# Spriteset_Map patch — toggle visibility of tilemap/characters for VN debug
#-----------------------------------------------------------------------------
class Spriteset_Map
  def vn_set_map_visible(v)
    if @tilemap
      @tilemap.visible = v
      @shadow_sprite.visible = v if instance_variable_defined?(:@shadow_sprite) && @shadow_sprite
      @parallax.visible = v if @parallax
    end
    if @character_sprites
      @character_sprites.each { |s| s.visible = v }
    end
  end
end

#-----------------------------------------------------------------------------
# Scene_Map hook — optional auto-enter VN on first map (disabled by default)
#-----------------------------------------------------------------------------
if VNConfig::AUTO_BOOT_VN
  class Scene_Map < Scene_Base
    alias_method :skip0s_vn_start_original, :start
    def start
      if VN.vn_mode? && !$vn_booted
        $vn_booted = true
        SceneManager.goto(Scene_VN)
        return
      end
      skip0s_vn_start_original
    end
  end
end

#-----------------------------------------------------------------------------
# Scene_Map compatibility shim — define pre_transfer/post_transfer if missing
#  Some custom bases/plugins alias these, and older edits may remove them.
#-----------------------------------------------------------------------------
class Scene_Map < Scene_Base
  unless instance_methods(false).include?(:pre_transfer)
    def pre_transfer; end
  end
  unless instance_methods(false).include?(:post_transfer)
    def post_transfer; end
  end
end

#-----------------------------------------------------------------------------
# Window_VNMessage — VN-styled message box (still driven by $game_message)
#-----------------------------------------------------------------------------
class Window_VNMessage < Window_Message
  def initialize
    super()
    rect = VNConfig::MESSAGE_WINDOW_OPTS
    self.x = rect[:x]
    self.y = rect[:y]
    self.width  = rect[:w]
    self.height = rect[:h]
    self.opacity = rect[:opacity]
    self.openness = 0
  end
end

#-----------------------------------------------------------------------------
# Window_ActionMenu — main action menu (Interagir, Andar / Sair)
#-----------------------------------------------------------------------------
class Window_ActionMenu < Window_Command
  def initialize(rect)
    @vn_mode = VN.vn_mode?
    @__w = rect.width
    @__h = rect.height
    super(rect.x, rect.y)
    refresh
    select(0)
    activate
  end

  def window_width;  @__w; end
  def window_height; @__h; end

  def make_command_list
    VNConfig::ACTION_MENU_ITEMS.each do |it|
      next if it[:show] == :vn_only      && !@vn_mode
      next if it[:show] == :overlay_only &&  @vn_mode
      enabled = true
      enabled = it[:enabled_if].call rescue enabled if it[:enabled_if]
      add_command(it[:label], it[:symbol], enabled)
    end
  end

  def refresh
    clear_command_list
    make_command_list
    super
  end
end

#-----------------------------------------------------------------------------
# Window_MoveDir — four-direction movement submenu for VN mode
#----------------------------------------------------------------------------- — four-direction movement submenu for VN mode
#-----------------------------------------------------------------------------
# — four-direction movement submenu for VN mode
#-----------------------------------------------------------------------------
class Window_MoveDir < Window_Command
  def initialize(rect)
    @__w = rect.width
    @__h = rect.height
    super(rect.x, rect.y)
    refresh
    select(0)
  end

  def window_width;  @__w; end
  def window_height; @__h; end

  def make_command_list
    add_command("Cima",  :up,    !VN.dir_blocked?(:up))
    add_command("Baixo", :down,  !VN.dir_blocked?(:down))
    add_command("Esq",   :left,  !VN.dir_blocked?(:left))
    add_command("Dir",   :right, !VN.dir_blocked?(:right))
    add_command("Voltar", :cancel)
  end

  def refresh
    clear_command_list
    make_command_list
    super
  end
end

#-----------------------------------------------------------------------------
# Window_VNTop — simple top HUD (map name, coords)
#-----------------------------------------------------------------------------
class Window_VNTop < Window_Base
  def initialize
    super(0, 0, Graphics.width, VNConfig::TOP_HUD_HEIGHT)
    self.opacity = 255
    refresh
  end

  def refresh
    contents.clear
    name = $game_map && $game_map.display_name ? $game_map.display_name : ""
    xy   = ($game_player ? "X:#{$game_player.x} Y:#{$game_player.y}" : "")
    draw_text(4, 0, contents.width/2, line_height, name)
    draw_text(contents.width/2, 0, contents.width/2-8, line_height, xy, 2)
  end
end

#-----------------------------------------------------------------------------
# Window_VNBar — persistent bottom bar (shows even with no messages)
#-----------------------------------------------------------------------------
class Window_VNBar < Window_Base
  def initialize
    h = VNConfig::MESSAGE_WINDOW_OPTS[:h]
    y = VNConfig::MESSAGE_WINDOW_OPTS[:y]
    super(0, y, Graphics.width, h)
    self.opacity = VNConfig::MESSAGE_WINDOW_OPTS[:opacity]
    refresh
  end

  def refresh
    contents.clear
    # Optional: show current tile description if any
    desc = VN.describe_area rescue nil
    draw_text(8, 0, contents.width-16, line_height, desc.to_s)
  end
end

# — common base for VN and Overlay scenes
#  - Keeps live map logic running (events/battle/transfer)
#  - Owns the VN message/choice windows
#  - Builds Spriteset_Map; hides tilemap/chars in VN unless DEBUG is ON
#-----------------------------------------------------------------------------
class Scene_VNBase < Scene_Base
  attr_reader :message_window

  def start
    super
    create_spriteset
    create_all_windows
    create_action_ui
    cache_toggle_states
  end

  def terminate
    super
    dispose_action_ui
    dispose_spriteset
  end

  def pre_transfer;  end
  def post_transfer; end

  # -- Map spriteset ----------------------------------------------------------
  def create_spriteset
    @spriteset = Spriteset_Map.new if defined?($game_map) && $game_map
    update_map_visibility
  end

  def update_map_visibility
    show_map = map_should_be_visible?
    @spriteset.vn_set_map_visible(show_map) if @spriteset
  end

  def map_should_be_visible?; true; end

  def dispose_spriteset
    @spriteset.dispose if @spriteset
  end

  # -- Windows ---------------------------------------------------------------
  def create_all_windows
    create_top_hud if VNConfig::SHOW_TOP_HUD
    create_dialogue_bar if VNConfig::SHOW_DIALOGUE_BAR
    create_message_window
    create_scroll_text_window
    create_number_input_window
    create_item_choice_window
    create_choice_list_window
  end

  def create_top_hud;       @top_hud = Window_VNTop.new;      end
  def create_dialogue_bar;  @vn_bar  = Window_VNBar.new;      end
  def create_message_window
    @message_window = Window_VNMessage.new
    @message_window.openness = 0
  end
  def create_scroll_text_window; @scroll_text_window = Window_ScrollText.new; end
  def create_number_input_window; @number_input_window = Window_NumberInput.new(@message_window); end
  def create_item_choice_window;  @item_choice_window  = Window_KeyItem.new(@message_window);    end
  def create_choice_list_window;  @choice_window       = Window_ChoiceList.new(@message_window); end

  # -- Action UI --------------------------------------------------------------
  def create_action_ui
    @action_menu = Window_ActionMenu.new(VNConfig.action_menu_rect)
    @move_menu   = Window_MoveDir.new(VNConfig.move_menu_rect)
    @move_menu.deactivate
    @move_menu.close
    bind_action_handlers
  end

  def dispose_action_ui
    [@action_menu, @move_menu].compact.each(&:dispose)
  end

  def bind_action_handlers
    VNConfig::ACTION_MENU_ITEMS.each do |it|
      sym = it[:symbol]
      case sym
      when :interact then @action_menu.set_handler(sym, method(:command_interact))
      when :move     then @action_menu.set_handler(sym, method(:command_move))
      when :exit     then @action_menu.set_handler(sym, method(:command_exit_overlay))
      else
        if it[:open_scene]
          klass = resolve_scene_class(it[:open_scene])
          if klass
            @action_menu.set_handler(sym, -> { SceneManager.call(klass) })
          else
            @action_menu.set_handler(sym, -> { Sound.play_buzzer })
          end
        elsif it[:on_select].respond_to?(:call)
          @action_menu.set_handler(sym, it[:on_select])
        else
          @action_menu.set_handler(sym, -> { Sound.play_buzzer })
        end
      end
    end
    @action_menu.set_handler(:cancel, method(:on_action_cancel))

    @move_menu.set_handler(:up,    -> { do_move(8) })
    @move_menu.set_handler(:down,  -> { do_move(2) })
    @move_menu.set_handler(:left,  -> { do_move(4) })
    @move_menu.set_handler(:right, -> { do_move(6) })
    @move_menu.set_handler(:cancel, method(:close_move_menu))
  end

  def resolve_scene_class(val)
    return val if val.is_a?(Class)
    name = val.is_a?(Symbol) ? val.to_s : val
    return Object.const_get(name) if name.is_a?(String)
    nil
  rescue NameError
    nil
  end

  def cache_toggle_states
    @__last_move_enabled = VN.move_enabled?
  end

  # -- Update loop ------------------------------------------------------------
  def update
    super
    update_basic_map_logic
    update_hud_visibility
    update_message_lock
    update_overlay_ok if overlay_ok_enabled?
    refresh_action_menu_if_needed
  end

  def update_basic_map_logic
    $game_map.update(true) if defined?($game_map) && $game_map
    $game_player.update    if defined?($game_player) && $game_player
    $game_timer.update     if defined?($game_timer) && $game_timer
    $game_screen.update    if defined?($game_screen) && $game_screen
    update_transfer_player
  end

  def update_transfer_player
    return unless defined?($game_player) && $game_player
    if $game_player.transfer?
      fade_for_transfer
      $game_player.perform_transfer
      on_player_transferred
      Graphics.frame_reset
    end
  end

  def fade_for_transfer; Graphics.fadeout(15); end

  def on_player_transferred
    @spriteset.dispose if @spriteset
    create_spriteset
  end

  def update_hud_visibility
    hidden = VN.hud_hidden?
    [@action_menu, @move_menu, @top_hud, @vn_bar].compact.each { |w| w.visible = !hidden }
    @top_hud.refresh if @top_hud && !hidden
    @vn_bar.refresh  if @vn_bar && !hidden && !$game_message.busy?
  end

  def overlay_ok_enabled?
    return false if VN.vn_mode?
    return false if VN.hud_hidden?
    return false if $game_message.busy?
    true
  end

  def update_overlay_ok
    if Input.trigger?(:C)
      trigger_tile_action
    end
  end

  def refresh_action_menu_if_needed
    if @__last_move_enabled != VN.move_enabled?
      @__last_move_enabled = VN.move_enabled?
      @action_menu.refresh if @action_menu
    end
  end

  def update_message_lock
    if $game_message && $game_message.busy?
      @action_menu.deactivate if @action_menu
      @move_menu.deactivate if @move_menu
    else
      @action_menu.activate if @action_menu && !(@move_menu && @move_menu.active)
    end
  end

  # -- Actions ----------------------------------------------------------------
  def command_interact; trigger_tile_action; end

  def trigger_tile_action
    return if $game_message.busy?
    $game_player.check_event_trigger_here([0]) if $game_player
  end

  def command_move
    return unless VN.vn_mode?
    return unless VN.move_enabled?
    @move_menu.open
    @move_menu.activate
  end

  def close_move_menu
    @move_menu.deactivate
    @move_menu.close
    @action_menu.activate if @action_menu
  end

  def do_move(dir)
    case dir
    when 8; return Sound.play_buzzer if VN.dir_blocked?(:up)
    when 2; return Sound.play_buzzer if VN.dir_blocked?(:down)
    when 4; return Sound.play_buzzer if VN.dir_blocked?(:left)
    when 6; return Sound.play_buzzer if VN.dir_blocked?(:right)
    end
    $game_player.move_straight(dir) if $game_player
    close_move_menu
  end

  def command_exit_overlay; SceneManager.return; end

  def on_action_cancel
    if $game_message && $game_message.busy?
      Sound.play_buzzer; return
    end
    if @move_menu && @move_menu.active
      close_move_menu
    else
      @action_menu.activate if @action_menu
    end
  end
end

#----------------------------------------------------------------------------- 
# Scene_VNOverlay — overlay mode (map visible; menu includes "Sair") — overlay mode (map visible; menu includes "Sair")
#-----------------------------------------------------------------------------
class Scene_VNOverlay < Scene_VNBase
  def map_should_be_visible?
    true
  end
end

#-----------------------------------------------------------------------------
# Scene_VN — VN mode (tilemap hidden; optional DEBUG shows the map)
#-----------------------------------------------------------------------------
class Scene_VN < Scene_VNBase
  def start
    super
    @__last_debug = VN.debug_map
    apply_debug_runtime_toggles
    ensure_debug_cursor
  end

  def update
    super
    if @__last_debug != VN.debug_map
      @__last_debug = VN.debug_map
      apply_debug_runtime_toggles
      update_map_visibility
      ensure_debug_cursor
    end
    update_debug_cursor
  end

  def terminate
    dispose_debug_cursor
    restore_through_if_needed
    super
  end

  def map_should_be_visible?; VN.debug_map; end

  # -- Debug helpers ----------------------------------------------------------
  def apply_debug_runtime_toggles
    return unless $game_player
    if VN.debug_map && VNConfig::DEBUG_FORCE_THROUGH
      @__saved_through ||= $game_player.through
      $game_player.through = true
    else
      restore_through_if_needed
    end
  end

  def restore_through_if_needed
    return unless $game_player
    unless @__saved_through.nil?
      $game_player.through = @__saved_through
      @__saved_through = nil
    end
  end

  def ensure_debug_cursor
    dispose_debug_cursor unless VN.debug_map && VNConfig::DEBUG_PLAYER_MARKER
    return unless VN.debug_map && VNConfig::DEBUG_PLAYER_MARKER
    return if @debug_cursor
    @debug_cursor = Sprite.new
    vp1 = @spriteset.instance_variable_get(:@viewport1) rescue nil
    @debug_cursor.viewport = vp1
    @debug_cursor.bitmap = Bitmap.new(12,12)
    b = @debug_cursor.bitmap
    c = Color.new(255,0,0)
    b.fill_rect(0,0,12,1,c); b.fill_rect(0,11,12,1,c)
    b.fill_rect(0,0,1,12,c); b.fill_rect(11,0,1,12,c)
    @debug_cursor.z = 5000
    update_debug_cursor
  end

  def update_debug_cursor
    return unless @debug_cursor && $game_player
    @debug_cursor.x = $game_player.screen_x - 6
    @debug_cursor.y = $game_player.screen_y - 6
    @debug_cursor.visible = VN.debug_map
  end

  def dispose_debug_cursor
    return unless @debug_cursor
    @debug_cursor.bitmap.dispose if @debug_cursor.bitmap
    @debug_cursor.dispose
    @debug_cursor = nil
  end
end

#-----------------------------------------------------------------------------
# BattleTransitionHelper — call from events if you want custom pre-battle fade
#-----------------------------------------------------------------------------
module BattleTransitionHelper
  def self.pre_battle
    case VNConfig::BATTLE_FADE_TYPE
    when :black; Graphics.fadeout(15)
    when :white; Graphics.fadeout(15, true)
    end
    VNConfig::BATTLE_TRANSITION.call if VNConfig::BATTLE_TRANSITION
  end
end

#-----------------------------------------------------------------------------
# Safety: disable arrow-key movement in pure VN mode (overlay keeps native input)
#-----------------------------------------------------------------------------
class Game_Player < Game_Character
  alias skip0s_vn_move_by_input move_by_input
  def move_by_input
    return if SceneManager.scene_is?(Scene_VN)
    skip0s_vn_move_by_input
  end
end
