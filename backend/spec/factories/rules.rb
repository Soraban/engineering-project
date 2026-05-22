FactoryBot.define do
  factory :rule do
    user
    name      { Faker::Lorem.sentence(word_count: 3) }
    condition { { 'field' => 'description', 'operator' => 'contains', 'value' => 'Amazon' } }
    action    { { 'type' => 'set_category', 'value' => 'Shopping' } }
    priority  { 0 }
    active    { true }
  end
end
