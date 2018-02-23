require "./src/oak"

tree = Oak::Tree(Symbol).new

tree.add("/1", :one)

puts tree.find("/2")
