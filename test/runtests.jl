using MusicIR
using Base.Test

println("Testing frame...")
test_arr = [1, 2, 3, 4, 5, 6]
@test frame(test_arr, 3) == hcat([1, 2, 3], [4, 5, 6])
@test frame(test_arr, 2) == hcat([1, 2], [3, 4], [5, 6])
@test frame(test_arr, 4, 2) == hcat([1, 2, 3, 4], [3, 4, 5, 6])
@test frame(test_arr, 3, 1) == hcat([1, 2, 3], [2, 3, 4], [3, 4, 5], [4, 5, 6])
@test frame(test_arr, 3, 2) == hcat([1, 2, 3], [3, 4, 5], [5, 6, 0])

println("Testing overlap_add...")
@test overlap_add(hcat([1, 2, 3], [4, 5, 6])) == test_arr
@test overlap_add(hcat([1, 2], [3, 4], [5, 6])) == test_arr
@test overlap_add(hcat([1, 2, 3, 4], [3, 4, 5, 6]), 2) == [1, 2, 6, 8, 5, 6]
@test overlap_add(hcat([1, 2, 3], [2, 3, 4], [3, 4, 5], [4, 5, 6]), 1) == [1, 4, 9, 12, 10, 6]
@test overlap_add(hcat([1, 2, 3], [3, 4, 5], [5, 6, 0]), 2) == [1, 2, 6, 4, 10, 6, 0]

println("Tests Passed")
