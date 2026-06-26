module PortalSeoHelper
  def seo_site_name
    "ADnull - #{I18n.t('public_portal.common.title')}"
  end

  def seo_title(page_title)
    return seo_site_name if page_title.blank?

    "#{page_title} | #{seo_site_name}"
  end

  def portal_base_url(portal)
    return "https://#{portal.custom_domain}" if portal.custom_domain.present?

    request.base_url
  end

  def portal_url(portal, path)
    "#{portal_base_url(portal)}#{path}"
  end

  def portal_locales(portal)
    Array(portal.config['allowed_locales']).presence || [portal.default_locale]
  end

  def seo_description(text, limit = 160)
    return if text.blank?

    plain = ChatwootMarkdownRenderer.new(text.to_s).render_markdown_to_plain_text
    plain.gsub(/\s+/, ' ').strip.truncate(limit, separator: ' ')
  end

  # ---- canonical paths (theme + plain layout always disabled for public SEO) ----

  def home_path_for(portal, locale)
    generate_home_link(portal.slug, locale, false, false)
  end

  def article_path_for(portal, article)
    generate_article_link(portal.slug, article.slug, false, false)
  end

  def category_path_for(portal, category)
    generate_category_link(
      portal_slug: portal.slug, category_locale: category.locale,
      category_slug: category.slug, theme: false, is_plain_layout_enabled: false
    )
  end

  # ---- hreflang alternates ----

  def portal_home_alternate_links(portal)
    portal_locales(portal).map do |locale|
      { hreflang: locale, href: portal_url(portal, home_path_for(portal, locale)) }
    end
  end

  def article_alternate_links(portal, article)
    root = article.root_article || article
    ([root] + root.associated_articles.to_a).uniq.select(&:published?).map do |variant|
      { hreflang: variant.locale, href: portal_url(portal, article_path_for(portal, variant)) }
    end
  end

  def category_alternate_links(portal, category)
    category_translation_variants(portal, category).map do |variant|
      { hreflang: variant.locale, href: portal_url(portal, category_path_for(portal, variant)) }
    end
  end

  # Translations are linked either explicitly (associated_category_id) or, as a
  # fallback for imported data, by sharing the same slug across locales.
  # Association links take precedence per locale.
  def category_translation_variants(portal, category)
    root = category.root_category || category
    candidates = [root] + root.associated_categories.to_a + categories_by_slug(portal)[category.slug].to_a
    candidates.each_with_object({}) { |variant, by_locale| by_locale[variant.locale] ||= variant }.values
  end

  # Memoized per request so the sitemap doesn't fire a slug lookup per category.
  def categories_by_slug(portal)
    (@categories_by_slug ||= {})[portal.id] ||= portal.categories.group_by(&:slug)
  end

  def article_breadcrumb_items(portal, article)
    locale = article.category&.locale || portal.default_locale
    items = [{ name: I18n.t('public_portal.common.home'), url: portal_url(portal, home_path_for(portal, locale)) }]
    items << { name: article.category.name, url: portal_url(portal, category_path_for(portal, article.category)) } if article.category
    items << { name: article.title, url: portal_url(portal, article_path_for(portal, article)) }
    items
  end

  def category_breadcrumb_items(portal, category)
    [
      { name: I18n.t('public_portal.common.home'), url: portal_url(portal, home_path_for(portal, category.locale)) },
      { name: category.name, url: portal_url(portal, category_path_for(portal, category)) }
    ]
  end
end
