module PagyStubHelper
  # PagyStub overrides #next and #prev but that's ok here
  # rubocop:disable Lint/StructNewOverride
  PagyStub = Struct.new(
    :page,
    :last,
    :next,
    :prev,
    :offset,
    :limit,
    :count
  )
  # rubocop:enable Lint/StructNewOverride

  # Usage with a real collection:
  #   pagy = pagy_stub_for(collection, page: 2, limit: 10)
  #
  # Usage with an integer to be assigned to count:
  #   pagy = pagy_stub_for(3, page: 2, limit: 10)
  #
  def pagy_stub_for(collection_or_count, page: 1, limit: 20)
    count =
      if collection_or_count.respond_to?(:count)
        collection_or_count.count
      else
        Integer(collection_or_count)
      end

    last   = (count.to_f / limit).ceil
    last   = 1 if last.zero? # behave nicely with empty collections
    page   = page.clamp(1, last)
    offset = (page - 1) * limit

    PagyStub.new(
      page: page,
      last: last,
      next: (page < last ? page + 1 : nil),
      prev: (page > 1 ? page - 1 : nil),
      offset: offset,
      limit: limit,
      count: count
    )
  end
end
