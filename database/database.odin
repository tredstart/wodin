package database

import "core:fmt"
import "core:testing"

Node :: struct {
	value:        int,
	branch_left:  ^Leaf,
	branch_right: ^Leaf,
	next:         ^Node,
	prev:         ^Node,
}

Leaf :: struct {
	count:  uint,
	head:   ^Node,
	tail:   ^Node,
	parent: ^Node,
}

Tree :: struct {
	root:  ^Leaf,
	order: uint,
}

Node_Iterator :: struct {
	idx: i32,
	tmp: ^Node,
}

next_node :: proc(it: ^Node_Iterator) -> (e: ^Node, idx: i32, ok: bool) {
	if it.tmp != nil {
		e, idx, ok = it.tmp, it.idx, true
		it.idx += 1
		it.tmp = it.tmp.next
	}
	return
}

insert_rec :: proc(leaf: ^Leaf, node: ^Node, value: int) -> ^Leaf {
	if value > node.value && node.branch_right == nil && node.next == nil {
		new_node := new(Node)
		new_node.value = value
		new_node.prev = node
		node.next = new_node
		leaf.count += 1
		leaf.tail = new_node
		return leaf
	}

	if value < node.value && node.branch_left == nil {
		new_node := new(Node)
		new_node.value = value
		new_node.next = node
		new_node.prev = node.prev
		node.prev = new_node
		leaf.count += 1
		if new_node.prev == nil {
			leaf.head = new_node
		} else {
			new_node.prev.next = new_node
		}
		return leaf
	}
	if value < node.value {
		return insert_rec(node.branch_left, node.branch_left.head, value)
	} else {
		if node.next == nil && node.branch_right != nil {
			return insert_rec(node.branch_right, node.branch_right.head, value)
		}
		return insert_rec(leaf, node.next, value)
	}
}

grow :: proc(left_leaf: ^Leaf) -> ^Node {
	it := Node_Iterator {
		tmp = left_leaf.head,
	}
	for _, i in next_node(&it) {
		if i == 1 do break
	}

	new_node := it.tmp
	new_node.branch_left = left_leaf

	right_leaf := new(Leaf)
	right_leaf.head = it.tmp.next
	right_leaf.head.prev = nil
	right_leaf.count = 2
	right_leaf.tail = left_leaf.tail
	new_node.branch_right = right_leaf

	left_leaf.tail = new_node.prev
	left_leaf.tail.next = nil
	left_leaf.count = 2

	new_node.prev = nil
	new_node.next = nil

	left_leaf.parent = new_node
	right_leaf.parent = new_node

	return new_node

}


insert_into_tree :: proc(tree: ^Tree, value: int) {
	root := tree.root
	if root.count == 0 {
		root.head = new(Node)
		root.tail = root.tail
		root.count += 1
		root.head.value = value
		return
	}
	leaf := insert_rec(tree.root, tree.root.head, value)
	if leaf.count == tree.order {
		parent := leaf.parent
		node := grow(leaf)
		if parent == nil {
			new_leaf := new(Leaf)
			new_leaf.count = 1
			new_leaf.head = node
			new_leaf.tail = node
			tree.root = new_leaf
		} else {
			if parent.value > node.value {
				if parent.prev != nil {
					parent.prev.next = node
				}
				node.prev = parent.prev
				node.next = parent
				parent.prev = node
			} else {
				if parent.next != nil {
					parent.next.prev = node
				}
				node.next = parent.next
				node.prev = parent
				parent.next = node
			}
		}
	}
}


print_list :: proc(list: ^Leaf) {
	it := Node_Iterator {
		tmp = list.head,
	}
	for node in next_node(&it) {
		fmt.eprintf("%p <- %p(%d) ->  %p\n", node.prev, node, node.value, node.next)
	}
}


burn_leaves :: proc(leaf: ^Leaf, visited: ^[dynamic]^Leaf) {
	if in_array(visited^, leaf) do return
	else do append(visited, leaf)
	leaf_iterator := Node_Iterator {
		tmp = leaf.head,
	}
	for node in next_node(&leaf_iterator) {
		if node.branch_left != nil do burn_leaves(node.branch_left, visited)
		if node.branch_right != nil do burn_leaves(node.branch_right, visited)
		free(node)
	}
	free(leaf)
}

burn_the_tree :: proc(tree: ^Tree) {
	visited_leaf := [dynamic]^Leaf{}
	defer delete(visited_leaf)
	burn_leaves(tree.root, &visited_leaf)
}

in_array :: proc(arr: [dynamic]^Leaf, value: ^Leaf) -> bool {
	for el in arr {
		if el == value do return true
	}
	return false
}

print_tree :: proc(leaf: ^Leaf, visited: ^[dynamic]^Leaf) {
	if in_array(visited^, leaf) do return
	else do append(visited, leaf)
	leaf_iterator := Node_Iterator {
		tmp = leaf.head,
	}
	for node in next_node(&leaf_iterator) {
		if node.branch_left != nil do print_tree(node.branch_left, visited)
		fmt.eprintln(node)
		if node.branch_right != nil do print_tree(node.branch_right, visited)
	}
}

@(test)
root_node_fills :: proc(t: ^testing.T) {
	tree := Tree{}
	tree.root = new(Leaf)
	tree.order = 5
	defer burn_the_tree(&tree)

	expected_root := []int{1, 3, 5, 7}
	insert_into_tree(&tree, expected_root[2])
	insert_into_tree(&tree, expected_root[3])
	insert_into_tree(&tree, expected_root[0])
	insert_into_tree(&tree, expected_root[1])
	it := Node_Iterator {
		tmp = tree.root.head,
	}
	for node, i in next_node(&it) {
		assert(node.value == expected_root[i])
	}
	new_root := []int{4, 6, 8, 9, 2, 15, 4223, 923, 42, 23, 12, 17, 14, 13, 10, 11}
	for nr in new_root {
		insert_into_tree(&tree, nr)
	}
	visited_print := [dynamic]^Leaf{}
	defer delete(visited_print)
	print_tree(tree.root, &visited_print)
	new_expect := []int{5, 8}
	it = Node_Iterator {
		tmp = tree.root.head,
	}
	for node, i in next_node(&it) {
		assert(node.value == new_expect[i])
	}
}

