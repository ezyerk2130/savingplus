import { useEffect, useState } from 'react'
import { BookOpen, Clock, ChevronLeft } from 'lucide-react'
import { contentApi } from '../api/services'
import { showLoadError } from '../utils/error'
import type { ContentArticle } from '../types'

const categories = ['All', 'Saving', 'Investing', 'Budgeting', 'Insurance', 'Credit']

const categoryStyle: Record<string, { bg: string; text: string; activeBg: string }> = {
  all: { bg: 'bg-navy-50', text: 'text-navy-600', activeBg: 'bg-navy-900 text-white' },
  saving: { bg: 'bg-green-50', text: 'text-green-700', activeBg: 'bg-green-600 text-white' },
  investing: { bg: 'bg-blue-50', text: 'text-blue-700', activeBg: 'bg-blue-600 text-white' },
  budgeting: { bg: 'bg-purple-50', text: 'text-purple-700', activeBg: 'bg-purple-600 text-white' },
  insurance: { bg: 'bg-amber-50', text: 'text-amber-700', activeBg: 'bg-amber-600 text-white' },
  credit: { bg: 'bg-red-50', text: 'text-red-700', activeBg: 'bg-red-600 text-white' },
}

export default function Learn() {
  const [articles, setArticles] = useState<ContentArticle[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(false)
  const [activeCategory, setActiveCategory] = useState('All')
  const [selectedArticle, setSelectedArticle] = useState<ContentArticle | null>(null)

  const loadArticles = (category?: string) => {
    setLoading(true)
    setError(false)
    const params = category && category !== 'All' ? { category: category.toLowerCase() } : {}
    contentApi.listArticles(params).then((res) => {
      setArticles(res.data.articles || [])
    }).catch((err: unknown) => {
      showLoadError(err, 'articles')
      setError(true)
    }).finally(() => setLoading(false))
  }

  useEffect(() => { loadArticles(activeCategory) }, [activeCategory])

  // Article read view
  if (selectedArticle) {
    const catKey = selectedArticle.category.toLowerCase()
    const cs = categoryStyle[catKey] || categoryStyle.all
    return (
      <div className="space-y-6">
        <button
          onClick={() => setSelectedArticle(null)}
          className="flex items-center gap-1.5 text-sm font-medium text-navy-500 hover:text-navy-700 transition-colors"
        >
          <ChevronLeft className="w-4 h-4" /> Back to articles
        </button>

        <article className="card">
          <div className="flex items-center gap-2 mb-4">
            <span className={`badge ${cs.bg} ${cs.text}`}>
              {selectedArticle.category}
            </span>
            <span className="flex items-center gap-1 text-2xs text-navy-400">
              <Clock className="w-3 h-3" /> {selectedArticle.read_time_min} min read
            </span>
          </div>

          {selectedArticle.image_url && (
            <img
              src={selectedArticle.image_url}
              alt={selectedArticle.title}
              className="w-full h-52 object-cover rounded-2xl mb-5"
            />
          )}

          <h1 className="text-2xl font-bold text-navy-900 mb-2">{selectedArticle.title}</h1>
          <p className="text-2xs text-navy-400 mb-6">
            {new Date(selectedArticle.created_at).toLocaleDateString('en-TZ', { year: 'numeric', month: 'long', day: 'numeric' })}
          </p>

          <div className="prose prose-sm max-w-none text-navy-700 leading-relaxed whitespace-pre-wrap">
            {selectedArticle.body}
          </div>
        </article>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Page header */}
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 bg-primary-50 rounded-xl flex items-center justify-center">
          <BookOpen className="w-5 h-5 text-primary-600" />
        </div>
        <div>
          <h1 className="text-2xl font-bold text-navy-900">Learn</h1>
          <p className="text-navy-400 text-sm">Financial literacy tips and guides</p>
        </div>
      </div>

      {/* Category filter chips */}
      <div className="flex gap-2 overflow-x-auto pb-1 -mx-1 px-1 scrollbar-hide">
        {categories.map((cat) => {
          const key = cat.toLowerCase()
          const cs = categoryStyle[key] || categoryStyle.all
          const isActive = activeCategory === cat
          return (
            <button
              key={cat}
              onClick={() => setActiveCategory(cat)}
              className={`px-4 py-2 rounded-2xl text-sm font-semibold whitespace-nowrap transition-all active:scale-[0.97] ${
                isActive ? cs.activeBg : `${cs.bg} ${cs.text} hover:opacity-80`
              }`}
            >
              {cat}
            </button>
          )
        })}
      </div>

      {loading ? (
        <div className="flex items-center justify-center h-64">
          <div className="animate-spin rounded-full h-8 w-8 border-2 border-primary-500 border-t-transparent" />
        </div>
      ) : error ? (
        <div className="card text-center py-16">
          <p className="text-navy-500 mb-4">Failed to load articles</p>
          <button onClick={() => loadArticles(activeCategory)} className="btn-primary">Retry</button>
        </div>
      ) : articles.length === 0 ? (
        <div className="card text-center py-16">
          <div className="w-16 h-16 bg-navy-50 rounded-2xl flex items-center justify-center mx-auto mb-4">
            <BookOpen className="w-8 h-8 text-navy-300" />
          </div>
          <p className="text-navy-500 font-medium">No articles available</p>
          <p className="text-navy-400 text-sm mt-1">
            {activeCategory !== 'All' ? `Nothing in ${activeCategory} yet` : 'Check back soon'}
          </p>
        </div>
      ) : (
        <div className="grid gap-4 sm:grid-cols-2">
          {articles.map((article) => {
            const catKey = article.category.toLowerCase()
            const cs = categoryStyle[catKey] || categoryStyle.all
            return (
              <button
                key={article.id}
                onClick={() => setSelectedArticle(article)}
                className="card text-left hover:border-primary-200 hover:shadow-md transition-all group"
              >
                {article.image_url && (
                  <img
                    src={article.image_url}
                    alt={article.title}
                    className="w-full h-36 object-cover rounded-2xl mb-3 group-hover:scale-[1.02] transition-transform"
                  />
                )}

                <div className="flex items-center gap-2 mb-2.5">
                  <span className={`badge ${cs.bg} ${cs.text}`}>
                    {article.category}
                  </span>
                  <span className="flex items-center gap-1 text-2xs text-navy-400">
                    <Clock className="w-3 h-3" /> {article.read_time_min} min
                  </span>
                </div>

                <h3 className="font-semibold text-navy-900 mb-1.5 group-hover:text-primary-700 transition-colors">
                  {article.title}
                </h3>
                <p className="text-2xs text-navy-400 line-clamp-2">
                  {article.body.slice(0, 120)}{article.body.length > 120 ? '...' : ''}
                </p>
              </button>
            )
          })}
        </div>
      )}
    </div>
  )
}
