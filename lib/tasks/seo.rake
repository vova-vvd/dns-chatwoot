# rubocop:disable Metrics/BlockLength

# A group is linkable only when it spans >=2 locales with at most one record per
# locale, so we never guess between two same-locale candidates.
def seo_unambiguous_group?(group)
  group.size >= 2 && group.map(&:locale).uniq.size == group.size
end

# Picks the default-locale record as root (or the first) and points every other
# record's translation foreign key at it. Returns nothing useful; callers report.
def seo_link_group(group, default_locale, foreign_key)
  root = group.find { |record| record.locale == default_locale } || group.first
  root.update_columns(foreign_key => nil) # rubocop:disable Rails/SkipsModelValidations
  (group - [root]).each { |record| record.update_columns(foreign_key => root.id) } # rubocop:disable Rails/SkipsModelValidations
end

namespace :seo do
  desc 'Generate SEO meta (title, description, keywords) for all articles from their content and overwrite existing meta'
  task generate_article_meta: :environment do
    scope = Article.all
    total = scope.count
    done = 0

    scope.find_each do |article|
      meta = Articles::SeoMetaBuilder.new(article).meta
      # update_column avoids bumping updated_at (sitemap lastmod) and skips the
      # embedding callback; meta changes don't need either.
      article.update_column(:meta, meta) # rubocop:disable Rails/SkipsModelValidations
      done += 1
      puts "[#{done}/#{total}] ##{article.id} #{article.locale} #{article.slug}" if (done % 10).zero? || done == total
    end

    puts "Done. Generated SEO meta for #{done} articles."
  end

  # Links article translations by a normalized slug topic-token so hreflang can
  # populate. Only links UNAMBIGUOUS groups (>=2 locales, at most one article per
  # locale). Ambiguous/single groups are reported, never guessed.
  desc 'Link article translations across locales via associated_article_id (unambiguous groups only)'
  task link_article_translations: :environment do
    stop = %w[a_dnull dns manager router setting settings how to set get up on in for an a using the of and your profile]
    norm = lambda do |slug|
      slug.sub(/\A\d+-/, '').split(/[^a-z0-9]+/i).map(&:downcase)
          .reject { |token| token.blank? || stop.include?(token) }.sort.join('-')
    end

    Portal.find_each do |portal|
      linked = []
      skipped = []
      portal.articles.group_by { |article| norm.call(article.slug) }.each do |token, arts|
        if seo_unambiguous_group?(arts)
          seo_link_group(arts, portal.default_locale, :associated_article_id)
          linked << [token, arts.sort_by(&:locale).map { |a| "#{a.locale}:#{a.id}" }]
        else
          skipped << arts.sort_by(&:locale).map { |a| "#{a.locale}:#{a.id} #{a.slug}" }
        end
      end

      puts "\n== Portal '#{portal.slug}' =="
      puts "Linked #{linked.size} translation groups (#{linked.sum { |_, a| a.size }} articles):"
      linked.each { |token, arts| puts "  [#{token}] #{arts.join('  ')}" }
      puts "\nSkipped #{skipped.size} ambiguous/single groups (review & link by hand):"
      skipped.each { |arts| puts "  - #{arts.join('  ||  ')}" }
    end
  end

  # Links category translations across locales via associated_category_id.
  # Matches by the set of root articles each category contains (reliable once
  # articles are linked), so it works even when category slugs/names diverge.
  # Run AFTER seo:link_article_translations.
  desc 'Link category translations across locales via associated_category_id (matched by shared articles)'
  task link_category_translations: :environment do
    Portal.find_each do |portal|
      groups = Hash.new { |hash, key| hash[key] = [] }
      portal.categories.includes(:articles).each do |category|
        roots = category.articles.map { |a| a.associated_article_id || a.id }.sort.uniq
        groups[roots] << category if roots.any?
      end

      linked = []
      groups.each_value do |cats|
        next unless seo_unambiguous_group?(cats)

        seo_link_group(cats, portal.default_locale, :associated_category_id)
        linked << cats.sort_by(&:locale).map { |c| "#{c.locale}:#{c.id}(#{c.slug})" }
      end

      puts "\n== Portal '#{portal.slug}' categories =="
      puts "Linked #{linked.size} category groups:"
      linked.each { |cats| puts "  #{cats.join('  ')}" }
    end
  end
end
# rubocop:enable Metrics/BlockLength
