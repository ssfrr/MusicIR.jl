using MusicIR
using Base.Test

println("Testing frame...")
test_arr = [1, 2, 3, 4, 5, 6]
@test frame(test_arr, 3) == hcat([1, 2, 3], [4, 5, 6])
@test frame(test_arr, 2) == hcat([1, 2], [3, 4], [5, 6])
@test frame(test_arr, 4, 2) == hcat([1, 2, 3, 4], [3, 4, 5, 6])
@test frame(test_arr, 3, 1) == hcat([1, 2, 3], [2, 3, 4], [3, 4, 5], [4, 5, 6])
@test frame(test_arr, 3, 2) == hcat([1, 2, 3], [3, 4, 5], [5, 6, 0])

println("Tests Passed")
