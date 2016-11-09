FactoryGirl.define do
  factory :avaliation do
    test_date    '03/02/2020'
    classes      '1'
    description  'Avaliation description'

    unity
    discipline
    classroom
    association :school_calendar, factory: :school_calendar_with_one_step
    test_setting
    test_setting_test
  end
end
