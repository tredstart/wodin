package database

import "core:fmt"
import "core:log"
import "core:math/rand"
import "core:mem"
import "core:slice"
import "core:testing"

ORDER :: 3
MIN :: 1

Leaf :: struct {
	items:    [dynamic]int,
	children: [dynamic]^Leaf,
	parent:   ^Leaf,
}

Tree :: struct {
	root: ^Leaf,
}

insert_value :: proc(leaf: ^Leaf, value: int) -> int {
	for el, i in leaf.items {
		if value < el {
			inject_at_elem(&leaf.items, i, value)
			assert(len(leaf.items) <= ORDER)
			return i
		}
	}
	append(&leaf.items, value)
	assert(len(leaf.items) <= ORDER)
	return len(leaf.items) - 1
}

insert_into_leaf :: proc(leaf: ^Leaf, pos, value: int) -> ^Leaf {
	assert(pos < len(leaf.items), fmt.tprintf("%v, %v, %d", leaf, pos, value))
	element := leaf.items[pos]
	if len(leaf.children) == 0 {
		insert_value(leaf, value)
		return leaf
	}

	if value < element {
		assert(leaf.children[pos] != nil)
		return insert_into_leaf(leaf.children[pos], 0, value)
	}

	if pos == len(leaf.items) - 1 {
		assert(leaf.children[len(leaf.children) - 1] != nil)
		return insert_into_leaf(leaf.children[len(leaf.children) - 1], 0, value)
	}

	return insert_into_leaf(leaf, pos + 1, value)
}

split_leaf :: proc(parent, child: ^Leaf) -> ^Leaf {
	mid := child.items[MIN]
	pos := insert_value(parent, mid)

	if len(parent.children) == 0 {
		parent.children = make([dynamic]^Leaf, 1)
	}

	left_child := new(Leaf)
	left_child.items = make([dynamic]int, MIN)
	right_child := new(Leaf)
	right_child.items = make([dynamic]int, MIN)
	left_child.parent = parent
	right_child.parent = parent
	copy(left_child.items[:MIN], child.items[:MIN])
	copy(right_child.items[:MIN], child.items[MIN + 1:])
	half := len(child.children) / 2

	left_child.children = make([dynamic]^Leaf, half)
	right_child.children = make([dynamic]^Leaf, half)
	if half > 0 {
		copy(left_child.children[:], child.children[:half])
		copy(right_child.children[:], child.children[half:])
	}

	parent.children[pos] = left_child
	inject_at(&parent.children, pos + 1, right_child)

	delete(child.items)
	delete(child.children)
	free(child)
	return parent
}

insert_into_tree :: proc(tree: ^Tree, value: int) {
	if tree.root.items == nil {
		tree.root = new(Leaf)
		append(&tree.root.items, value)
		return
	}

	leaf := insert_into_leaf(tree.root, 0, value)
	for len(leaf.items) == ORDER {
		parent := leaf.parent
		if parent == nil {
			parent = new(Leaf)
			parent.items = make([dynamic]int, 0)
		}
		leaf = split_leaf(parent, leaf)
	}
	if leaf.parent == nil do tree.root = leaf
}


delete_tree :: proc(leaf: ^Leaf) {
	for child in leaf.children {
		delete_tree(child)
	}
	delete(leaf.children)
	delete(leaf.items)
	free(leaf)
}

gen_result :: proc(leaf: ^Leaf, result: ^[dynamic]int) {
	for item, i in leaf.items {
		if len(leaf.children) > 0 do gen_result(leaf.children[i], result)
		append(result, item)
		if len(leaf.children) > 0 && i == len(leaf.items) - 1 do gen_result(leaf.children[i + 1], result)
	}
}

print_tree :: proc(leaf: ^Leaf) {
	for item, i in leaf.items {
		if len(leaf.children) > 0 do print_tree(leaf.children[i])
		log.warn(leaf)
		if len(leaf.children) > 0 && i == len(leaf.items) - 1 do print_tree(leaf.children[i + 1])
	}
}

@(test)
b_tree_insertion :: proc(t: ^testing.T) {
	tree := Tree{}
	tree.root = new(Leaf)
	defer free(tree.root)
	defer delete_tree(tree.root)
	test_data := make([]int, 9)
	defer delete(test_data)
	for &el in test_data {
		el = cast(int)(rand.float64() * 1000)
	}
	log.warn("test data:", test_data)
	for el in test_data {
		insert_into_tree(&tree, el)
	}
	slice.sort(test_data)
	result := [dynamic]int{}
	defer delete(result)
	gen_result(tree.root, &result)
	log.warn("result: ", result)
	print_tree(tree.root)
	assert(len(result) == len(test_data))
	for el, i in test_data {
		assert(el == result[i])
	}
}

