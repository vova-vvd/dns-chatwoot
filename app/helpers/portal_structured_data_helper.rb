module PortalStructuredDataHelper
  def website_jsonld(home_url, search_url)
    schema_doc('WebSite',
               'name' => seo_site_name,
               'url' => home_url,
               'potentialAction' => {
                 '@type' => 'SearchAction',
                 'target' => { '@type' => 'EntryPoint', 'urlTemplate' => "#{search_url}?query={search_term_string}" },
                 'query-input' => 'required name=search_term_string'
               })
  end

  def organization_jsonld(portal)
    base = portal_base_url(portal)
    schema_doc('Organization', 'name' => seo_site_name, 'url' => base, 'logo' => "#{base}/favicon.ico")
  end

  def article_jsonld(article, canonical, description, image_url)
    author = { '@type' => 'Person', 'name' => article.author.name } if article.author&.name.present?
    schema_doc('TechArticle',
               'headline' => article.title,
               'datePublished' => article.created_at.iso8601,
               'dateModified' => article.updated_at.iso8601,
               'mainEntityOfPage' => canonical,
               'publisher' => { '@type' => 'Organization', 'name' => seo_site_name },
               'description' => description,
               'image' => image_url,
               'author' => author)
  end

  def collection_page_jsonld(name, url, description)
    schema_doc('CollectionPage', 'name' => name, 'url' => url, 'description' => description)
  end

  def breadcrumb_jsonld(items)
    schema_doc('BreadcrumbList',
               'itemListElement' => items.each_with_index.map do |item, index|
                 { '@type' => 'ListItem', 'position' => index + 1, 'name' => item[:name], 'item' => item[:url] }
               end)
  end

  private

  # Wraps schema.org attrs with the shared @context/@type and drops blank values
  # so optional keys (description, image, author) are omitted when absent.
  def schema_doc(type, attrs)
    { '@context' => 'https://schema.org', '@type' => type }.merge(attrs.reject { |_, value| value.blank? })
  end
end
