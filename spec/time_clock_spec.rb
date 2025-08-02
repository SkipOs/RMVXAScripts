require_relative '../TimeClock'

RSpec.describe TimeClock do
  context 'incrementing months' do
    it 'increments from November to December' do
      TimeClock.set_day(30)
      TimeClock.set_week_day(0)
      TimeClock.set_period(TimeClock::ConfigSetting::PERIODCOUNT)
      TimeClock.set_month(10) # November
      TimeClock.set_year(2023)

      TimeClock.clock_tick

      expect(TimeClock.day).to eq(1)
      expect(TimeClock.month_name).to eq('Dezembro')
    end

    it 'increments from December to January with year increment' do
      TimeClock.set_day(31)
      TimeClock.set_week_day(0)
      TimeClock.set_period(TimeClock::ConfigSetting::PERIODCOUNT)
      TimeClock.set_month(11) # December
      TimeClock.set_year(2023)

      TimeClock.clock_tick

      expect(TimeClock.day).to eq(1)
      expect(TimeClock.month_name).to eq('Janeiro')
      expect(TimeClock.year).to eq(2024)
    end
  end
end
