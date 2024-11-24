package database

import "core:fmt"
import "core:log"
import "core:math/rand"
import "core:mem"
import "core:slice"
import "core:testing"

ORDER :: 5
MIN :: 2
MAX :: 4

Leaf :: struct {
	items:    [ORDER]int,
	children: [ORDER + 1]^Leaf,
	parent:   ^Leaf,
	count:    int,
}

Tree :: struct {
	root: ^Leaf,
}

inject_in_slice :: proc(src: []$T, item: T, pos: int) {
	assert(pos <= len(src))
	copy(src[pos + 1:], src[pos:])
	src[pos] = item
}

insert_value :: proc(leaf: ^Leaf, value: int) -> int {
	for el, i in leaf.items {
		if value < el {
			inject_in_slice(leaf.items[:], value, i)
			leaf.count += 1
			assert(leaf.count <= ORDER)
			return i
		}
	}
	inject_in_slice(leaf.items[:], value, leaf.count)
	leaf.count += 1
	assert(leaf.count <= ORDER)
	return leaf.count - 1
}

insert_into_leaf :: proc(leaf: ^Leaf, pos, value: int) -> ^Leaf {
	if leaf.children[0] == nil {
		insert_value(leaf, value)
		return leaf
	}

	assert(pos < leaf.count)

	if value < leaf.items[pos] {
		assert(leaf.children[pos] != nil)
		return insert_into_leaf(leaf.children[pos], 0, value)
	}

	if pos == leaf.count - 1 {
		assert(leaf.children[pos + 1] != nil)
		return insert_into_leaf(leaf.children[pos + 1], 0, value)
	}

	return insert_into_leaf(leaf, pos + 1, value)
}

split_leaf :: proc(parent, left_child: ^Leaf) -> ^Leaf {
	mid := left_child.items[MIN]
	pos := insert_value(parent, mid)

	right_child := new(Leaf)

	left_child.parent = parent
	right_child.parent = parent
	right_child.count = MIN

	copy(right_child.items[:MIN], left_child.items[MIN + 1:])
	half := left_child.count / 2 + 1

	copy(right_child.children[:], left_child.children[half:])
	for child in right_child.children {
		if child != nil && child.parent != nil do child.parent = right_child
	}
	slice.zero(left_child.children[half:])
	slice.zero(left_child.items[MIN:])
	left_child.count = MIN

	parent.children[pos] = left_child
	inject_in_slice(parent.children[:], right_child, pos + 1)

	return parent
}

insert_into_tree :: proc(tree: ^Tree, value: int) {
	if tree.root.count == 0 {
		tree.root.items[0] = value
		tree.root.count += 1
		return
	}

	leaf := insert_into_leaf(tree.root, 0, value)
	for leaf.count == ORDER {
		parent := leaf.parent
		if parent == nil {
			parent = new(Leaf)
		}
		leaf = split_leaf(parent, leaf)
	}
	if leaf.parent == nil do tree.root = leaf
}


delete_tree :: proc(leaf: ^Leaf) {
	for child in leaf.children {
		if child != nil do delete_tree(child)
	}
	free(leaf)
}

gen_result :: proc(leaf: ^Leaf, result: ^[dynamic]int) {
	for item, i in leaf.items {
		if i >= leaf.count do break
		if leaf.children[i] != nil do gen_result(leaf.children[i], result)
		append(result, item)
		if i == leaf.count - 1 && leaf.children[leaf.count] != nil do gen_result(leaf.children[leaf.count], result)
	}
}

print_tree :: proc(leaf: ^Leaf) {
	for item, i in leaf.items {
		if i >= leaf.count do break
		if leaf.children[i] != nil do print_tree(leaf.children[i])
		log.warn(item)
		if i == leaf.count - 1 && leaf.children[leaf.count] != nil do print_tree(leaf.children[leaf.count])
	}
}


delete_from_tree :: proc(leaf: ^Leaf, value: int) {
	has_children := leaf.children[0] != nil
	for item, i in leaf.items {
		if value == item {
			if leaf.count > MIN {
				copy_slice(leaf.items[i:], leaf.items[i + 1:])
				leaf.count -= 1
			}
		}
		if value < item {
			if has_children {
				delete_from_tree(leaf.children[i], value)
			} else {
				log.warn("value not found", value)
				return
			}
		} else {
			// move either to the right children or next element
		}
	}
}

@(test)
b_tree_insertion :: proc(t: ^testing.T) {
	tree := Tree{}
	tree.root = new(Leaf)
	defer delete_tree(tree.root)
	test_data := make([]int, 10)
	defer delete(test_data)
	for &el in test_data {
		el = cast(int)(rand.float64() * 1000)
	}
	log.warn("*INSERTION* test data:", test_data)
	for el in test_data {
		insert_into_tree(&tree, el)
	}
	slice.sort(test_data)
	result := [dynamic]int{}
	defer delete(result)
	gen_result(tree.root, &result)
	log.warn("*INSERTION* result: ", result)
	assert(len(result) == len(test_data))
	for el, i in test_data {
		assert(el == result[i])
	}
}

@(test)
b_tree_delete_leaf :: proc(t: ^testing.T) {
	tree := Tree{}
	tree.root = new(Leaf)
	defer delete_tree(tree.root)
	size := MIN + 1
	test_data := make([]int, size)
	copy_test := make([]int, size / 2)
	defer delete(copy_test)
	defer delete(test_data)
	for &el, i in test_data {
		el = cast(int)(rand.float64() * 1000)
	}
	for el in test_data {
		insert_into_tree(&tree, el)
	}
	copy_slice(copy_test, test_data)
	slice.sort(test_data)
	slice.sort(copy_test)
	log.warn("#DELETION# test data:", test_data)
	log.warn("#DELETION# copy data:", copy_test)

	for el in copy_test {
		delete_from_tree(tree.root, el)
	}

	result := [dynamic]int{}
	defer delete(result)
	gen_result(tree.root, &result)

	log.warn("#DELETION# result: ", result)
	assert(len(result) == len(test_data) - 1)
	cp_counter := 0
	result_counter := 0
	for el in test_data {
		if cp_counter < len(copy_test) && el == copy_test[cp_counter] {
			cp_counter += 1
			continue
		}
		assert(result[result_counter] == el, fmt.tprintf("%d != %d", result[result_counter], el))
		result_counter += 1
	}
}
