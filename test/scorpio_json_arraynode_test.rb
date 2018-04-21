require_relative 'test_helper'

describe Scorpio::JSON::ArrayNode do
  # document of the node being tested
  let(:document) { ['a', ['b', 'q'], {'c' => {'d' => 'e'}}] }
  # by default the node is the whole document
  let(:path) { [] }
  # the node being tested
  let(:node) { Scorpio::JSON::Node.new_by_type(document, path) }

  describe '#each' do
    it 'iterates, one argument' do
      out = []
      node.each do |arg|
        out << arg
      end
      assert_instance_of(Scorpio::JSON::ArrayNode, node[1])
      assert_instance_of(Scorpio::JSON::HashNode, node[2])
      assert_equal(['a', node[1], node[2]], out)
    end
    it 'returns self' do
      assert_equal(node.each { }.object_id, node.object_id)
    end
    it 'returns an enumerator when called with no block' do
      enum = node.each
      assert_instance_of(Enumerator, enum)
      assert_equal(['a', node[1], node[2]], enum.to_a)
    end
  end
  describe '#to_ary' do
    it 'returns a Array with Nodes in' do
      assert_instance_of(Array, node.to_ary)
      assert_equal(['a', node[1], node[2]], node.to_ary)
    end
  end
  describe '#as_json' do
    let(:document) { ['a', 'b'] }
    it '#as_json' do
      assert_equal(['a', 'b'], node.as_json)
    end
  end
  # these methods just delegate to Array so not going to test excessively
  describe 'index only methods' do
    it('#each_index') { assert_equal([0, 1, 2], node.each_index.to_a) }
    it('#empty?')     { assert_equal(false, node.empty?) }
    it('#length')     { assert_equal(3, node.length) }
    it('#size')       { assert_equal(3, node.size) }
  end
  describe 'index + element methods' do
    it('#|')                    { assert_equal(['a', node[1], node[2], 0], node | [0]) }
    it('#&')                    { assert_equal(['a'], node & ['a']) }
    it('#*')                    { assert_equal(node.to_a, node * 1) }
    it('#+')                    { assert_equal(node.to_a, node + []) }
    it('#-')                    { assert_equal([node[1], node[2]], node - ['a']) }
    it('#<=>')                  { assert_equal(1, node <=> []) }
    it('#<=>')                  { assert_equal(-1, [] <=> node) }
    require 'abbrev'
    it('#abbrev')               { assert_equal({'a' => 'a'}, Scorpio::JSON::Node.new_by_type(['a'], []).abbrev) }
    it('#assoc')                { assert_equal(['b', 'q'], node.assoc('b')) }
    it('#at')                   { assert_equal('a', node.at(0)) }
    it('#bsearch')              { assert_equal(nil, node.bsearch { false }) }
    it('#bsearch_index')        { assert_equal(nil, node.bsearch_index { false }) } if [].respond_to?(:bsearch_index)
    it('#combination')          { assert_equal([['a'], [node[1]], [node[2]]], node.combination(1).to_a) }
    it('#count')                { assert_equal(1, node.count('a')) }
    it('#cycle')                { assert_equal(node.to_a, node.cycle(1).to_a) }
    it('#dig')                  { assert_equal('e', node.dig(2, 'c', 'd')) } if [].respond_to?(:dig)
    it('#drop')                 { assert_equal([node[2]], node.drop(2)) }
    it('#drop_while')           { assert_equal([node[1], node[2]], node.drop_while { |e| e == 'a' }) }
    it('#fetch')                { assert_equal('a', node.fetch(0)) }
    it('#find_index')           { assert_equal(0, node.find_index { true }) }
    it('#first')                { assert_equal('a', node.first) }
    it('#include?')             { assert_equal(true, node.include?('a')) }
    it('#index')                { assert_equal(0, node.index('a')) }
    it('#join')                 { assert_equal('a b', Scorpio::JSON::Node.new_by_type(['a', 'b'], []).join(' ')) }
    it('#last')                 { assert_equal(node[2], node.last) }
    it('#pack')                 { assert_equal(' ', Scorpio::JSON::Node.new_by_type([32], []).pack('c')) }
    it('#permutation')          { assert_equal([['a'], [node[1]], [node[2]]], node.permutation(1).to_a) }
    it('#product')              { assert_equal([], node.product([])) }
    # due to differences in implementation between #assoc and #rassoc, the reason for which
    # I cannot begin to fathom, assoc works but rassoc does not because rassoc has different
    # type checking than assoc for the array(like) array elements.
    # compare:
    # assoc:  https://github.com/ruby/ruby/blob/v2_5_0/array.c#L3780-L3813
    # rassoc: https://github.com/ruby/ruby/blob/v2_5_0/array.c#L3815-L3847
    # for this reason, rassoc is NOT defined on Arraylike and #content must be called.
    it('#rassoc')               { assert_equal(['b', 'q'], node.content.rassoc('q')) }
    it('#repeated_combination') { assert_equal([[]], node.repeated_combination(0).to_a) }
    it('#repeated_permutation') { assert_equal([[]], node.repeated_permutation(0).to_a) }
    it('#reverse')              { assert_equal([node[2], node[1], 'a'], node.reverse) }
    it('#reverse_each')         { assert_equal([node[2], node[1], 'a'], node.reverse_each.to_a) }
    it('#rindex')               { assert_equal(0, node.rindex('a')) }
    it('#rotate')               { assert_equal([node[1], node[2], 'a'], node.rotate) }
    it('#sample')               { assert_equal('a', Scorpio::JSON::Node.new_by_type(['a'], []).sample) }
    it('#shelljoin')            { assert_equal('a', Scorpio::JSON::Node.new_by_type(['a'], []).shelljoin) } if [].respond_to?(:shelljoin)
    it('#shuffle')              { assert_equal(3, node.shuffle.size) }
    it('#slice')                { assert_equal(['a'], node.slice(0, 1)) }
    it('#sort')                 { assert_equal(['a'], Scorpio::JSON::Node.new_by_type(['a'], []).sort) }
    it('#take')                 { assert_equal(['a'], node.take(1)) }
    it('#take_while')           { assert_equal([], node.take_while { false }) }
    it('#transpose')            { assert_equal([], Scorpio::JSON::Node.new_by_type([], []).transpose) }
    it('#uniq')                 { assert_equal(node.to_a, node.uniq) }
    it('#values_at')            { assert_equal(['a'], node.values_at(0)) }
    it('#zip')                  { assert_equal([['a', 'a'], [node[1], node[1]], [node[2], node[2]]], node.zip(node)) }
  end
  describe 'modified copy methods' do
    it('#reject')  { assert_equal(Scorpio::JSON::Node.new_by_type(['a'], []), node.reject { |e| e != 'a' }) }
    it('#select')  { assert_equal(Scorpio::JSON::Node.new_by_type(['a'], []), node.select { |e| e == 'a' }) }
    it('#compact') { assert_equal(node, node.compact) }
  end
  Scorpio::Arraylike::DESTRUCTIVE_METHODS.each do |destructive_method_name|
    it("does not respond to destructive method #{destructive_method_name}") do
      assert(!node.respond_to?(destructive_method_name))
    end
  end
end