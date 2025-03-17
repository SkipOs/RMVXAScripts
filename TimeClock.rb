#===========================================================================
# - TimeClock for Vx Ace
# A script that add time ticking and can be called inside the game
#===========================================================================
# - by Skip0s
# - ver 1.0
#===========================================================================

module TimeClock
  #===========================================================================
  # - Global Time Variables
  #===========================================================================
  @day = 16
  @week_day = 6
  @period = 3
  @month = 3
  @year = 2025
  
  module ConfigSetting
    #===========================================================================
    # - Period Day Name def (0 = Early Morning)
    #===========================================================================
    # You can change the names of all sections, or even 
    # add more periods if you want    
    #===========================================================================
    PERIODDAY = ["Manhã", "Tarde", "Noite"]
    PERIODCOUNT = PERIODDAY.size - 1
    
    #===========================================================================
    # - Month Name def (0 = January)
    #===========================================================================
    MONTH = ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho", "Julho", "Agosto", "Setembro", "Outubro", "Novembro"]
    MONTHCOUNT = MONTH.size - 1
    
    #===========================================================================
    # - Week Day Name def (0 = Sunday)
    #===========================================================================
    WEEKDAY = ["Domingo", "Segunda", "Terça", "Quarta", "Quinta", "Sexta", "Sábado"]
    WEEKDAYCOUNT = WEEKDAY.size - 1
  end #Config Setting

  #===========================================================================
  # - DANGER - 
  #===========================================================================
  # Do NOT change things below here if you don't know 
  # what are you doing. 
  #===========================================================================
  # - Methods for getting time 
  #===========================================================================
  def self.day
    @day
  end

  def self.week_day
    ConfigSetting::WEEKDAY[@week_day]
  end

  def self.period
    ConfigSetting::PERIODDAY[@period]
  end

  def self.month
    ConfigSetting::MONTH[@month]
  end

  def self.year
    @year
  end
  
  #===========================================================================
  # - Methods for time definition 
  #==========================================================================
  def self.set_day(value)
    @day = [[value, 1].max, 31].min
  end

  def self.set_week_day(value)
    @week_day = [[value, 0].max, ConfigSetting::WEEKDAYCOUNT].min
  end

  def self.set_period(value)
    @period = [[value, 0].max, ConfigSetting::PERIODCOUNT].min
  end

  def self.set_month(value)
    @month = [[value, 0].max, ConfigSetting::MONTHCOUNT].min
  end

  def self.set_year(value)
    @year = [value, 1].max
  end

  #===========================================================================
  # - Method for time passing 
  #===========================================================================
  def self.clock_tick
    @period += 1
    
    if @period > ConfigSetting::PERIODCOUNT
      @period = 0
      @week_day += 1
      @day += 1

      @week_day = 0 if @week_day > ConfigSetting::WEEKDAYCOUNT

      if (@day > 30 && @month != 1) || 
         (@day > 31 && [0, 2, 4, 6, 7, 9, 11].include?(@month)) || 
         (@day > 29 && @month == 1) 
        @day = 1
        @month += 1
      end

      if @month > ConfigSetting::MONTHCOUNT
        @month = 0
        @year += 1
      end
    end
  end
end

#===========================================================================
# - Method Calling
#===========================================================================
class Game_Interpreter
  def clock_tick
    TimeClock.clock_tick
  end

  def clock_day
    TimeClock.day
  end

  def clock_weekday
    TimeClock.week_day
  end

  def clock_period
    TimeClock.period
  end

  def clock_month
    TimeClock.month
  end

  def clock_year
    TimeClock.year
  end

  def set_day(value)
    TimeClock.set_day(value)
  end

  def set_weekday(value)
    TimeClock.set_week_day(value)
  end

  def set_period(value)
    TimeClock.set_period(value)
  end

  def set_month(value)
    TimeClock.set_month(value)
  end

  def set_year(value)
    TimeClock.set_year(value)
  end
end