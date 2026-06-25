module PortalStructuredDataHelper
  def website_jsonld(home_url, search_url)
    {
      '@context' => 'https://schema.org',
      '@type' => 'WebSite',
      'name' => seo_site_name,
      'url' => home_url,
      'potentialAction' => {
        '@type' => 'SearchAction',
        'target' => { '@type' => 'EntryPoint', 'urlTemplate' => "#{search_url}?query={search_term_string}" },
        'query-input' => 'required name=search_term_string'
      }
    }
  end

  def organization_jsonld(portal)
    base = portal_base_url(portal)
    { '@context' => 'https://schema.org', '@type' => 'Organization', 'name' => seo_site_name, 'url' => base, 'logo' => "#{base}/favicon.ico" }
  end

  def article_jsonld(article, canonical, description, image_url)
    data = {
      '@context' => 'https://schema.org',
      '@type' => 'TechArticle',
      'headline' => article.title,
      'datePublished' => article.created_at.iso8601,
      'dateModified' => article.updated_at.iso8601,
      'mainEntityOfPage' => canonical,
      'publisher' => { '@type' => 'Organization', 'name' => seo_site_name }
    }
    data['description'] = description if description.present?
    data['image'] = image_url if image_url.present?
    data['author'] = { '@type' => 'Person', 'name' => article.author.name } if article.author&.name.present?
    data
  end

  def collection_page_jsonld(name, url, description)
    data = { '@context' => 'https://schema.org', '@type' => 'CollectionPage', 'name' => name, 'url' => url }
    data['description'] = description if description.present?
    data
  end

  def breadcrumb_jsonld(items)
    {
      '@context' => 'https://schema.org',
      '@type' => 'BreadcrumbList',
      'itemListElement' => items.each_with_index.map do |item, index|
        { '@type' => 'ListItem', 'position' => index + 1, 'name' => item[:name], 'item' => item[:url] }
      end
    }
  end
end
