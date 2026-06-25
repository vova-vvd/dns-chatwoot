# Builds SEO-friendly meta (title, description, keywords) from an article's
# content using heuristics (no LLM). The description is extracted from the
# first real prose paragraph rather than a blind truncation of the raw body.
class Articles::SeoMetaBuilder
  DESCRIPTION_LIMIT = 160
  MAX_KEYWORDS = 12
  STOPWORDS = %w[
    the a an and or but for to of on in at by with from into your you i we it is are be can how
    what when where why this that these those will do does using use up set get a_dnull
    как что это для при или нужно перед через ваш вашем вашего вашей все всё так его чтобы если можно есть на не и
    як що це для при або потрібно перед через ваш вашому вашого вашій всі так його щоб якщо можна є на та не і
  ].freeze

  def initialize(article)
    @article = article
  end

  # Returns a new meta hash, overwriting the SEO keys while preserving any others.
  def meta
    @article.meta.to_h.merge('title' => title, 'description' => description, 'tags' => keywords).compact
  end

  def title
    @article.title.to_s.strip.presence
  end

  def description
    text = prose_text
    return if text.blank?

    smart_truncate(text, DESCRIPTION_LIMIT)
  end

  def keywords
    terms = [@article.category&.name, *significant_words(@article.title), *heading_terms]
    terms.compact.map { |term| term.downcase.strip }.reject(&:blank?).uniq.first(MAX_KEYWORDS)
  end

  private

  # First prose paragraph(s) of the content, markdown stripped. Skips headings,
  # lists, code blocks, images and tables. Joins a second paragraph when the
  # first is short so the description can fill closer to the limit.
  def prose_text
    blocks = @article.content.to_s.split(/\r?\n\s*\r?\n/)
    prose = blocks.filter_map { |block| clean_inline(block) if prose_block?(block) }
    return if prose.empty?

    text = prose.first
    text = "#{text} #{prose.second}" if text.length < 100 && prose.second.present?
    text.gsub(/\s+/, ' ').strip
  end

  def prose_block?(block)
    stripped = block.to_s.strip
    return false if stripped.length < 40

    !stripped.match?(/\A(#|```|>|\||!\[|[*+\-]\s|\d+\.\s)/)
  end

  def clean_inline(block)
    block.to_s
         .gsub(/!\[[^\]]*\]\([^)]*\)/, '')          # images
         .gsub(/\[([^\]]+)\]\([^)]*\)/, '\1')        # links -> text
         .gsub(/[*_~`#]+/, '')                       # bold/italic/code/heading marks
         .tr('\\', ' ')                              # stray escapes
         .gsub(/\s+/, ' ')
         .strip
  end

  def smart_truncate(text, limit)
    return text if text.length <= limit

    window = text[0, limit]
    sentence_end = window.rindex(/[.!?]/)
    return window[0..sentence_end].strip if sentence_end && sentence_end >= limit * 0.6

    cut = window.rindex(' ') || limit
    "#{window[0, cut].sub(/[^\p{Word}]+\z/, '').strip}…"
  end

  def heading_terms
    @article.content.to_s.scan(/^\#{1,6}\s+(.+)$/).flatten.flat_map { |heading| significant_words(heading) }
  end

  def significant_words(text)
    text.to_s.downcase.scan(/[\p{Alnum}]{3,}/).reject { |word| STOPWORDS.include?(word) }
  end
end
