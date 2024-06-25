# frozen_string_literal: true
require_relative 'test_helper'

describe("each_link_page") do
  it("paginates articles index") do
    5.times.map { |i| Article.post('title' => "#{i + 1}!") }

    index_operation = BlogModel.openapi_document.operations['articles.index']
    assert_titles = proc do |titles, **param|
      assert_equal(titles, index_operation.each_link_page(query_params: param).map { |ur| ur.response.body_object.map(&:title) })
    end
    assert_titles.([['1!', '2!'], ['3!', '4!'], ['5!']], per_page: 2)
    assert_titles.([['1!', '2!', '3!', '4!', '5!']], per_page: 5)
    assert_titles.([['5!']], per_page: 4, page: 2)
  end
end
