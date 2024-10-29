#!/usr/bin/ruby

require 'rubygems'
require 'ambit'

@solutions = []

def choose_group_of_3(remaining_items, groups)
  Ambit.assert(@solutions.none? { |previous| (previous & groups).length.positive? })
  return groups if remaining_items.size < 3

  group = [
    Ambit.choose(remaining_items),
    Ambit.choose(remaining_items),
    Ambit.choose(remaining_items)
  ].sort

  Ambit.assert(group.uniq.length == group.length) # no dups

  choose_group_of_3(remaining_items.reject { |item| group.include?(item) }, groups + [group])
end

def solve
  items = (1..12).to_a

  begin
    solution = choose_group_of_3(items, [])
    @solutions << solution
    p solution
  rescue Ambit::ChoicesExhausted
  end
end

100.times do
  solve
end
