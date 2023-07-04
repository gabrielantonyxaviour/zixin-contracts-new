if (!secrets.accessToken) {
  throw Error("ACCESS TOKEN required to fetch data from GitHub. Please add it to the secrets in your request.")
}

if (!secrets.imageApiKey) {
  throw Error("Image API Key required to fetch data from Image API. Please add it to the secrets in your request.")
}

if (!secrets.nftStorageApiKey) {
  throw Error(
    "NFT Storage API Key required to fetch data from NFT Storage API. Please add it to the secrets in your request."
  )
}
console.log(secrets.accessToken)
const profileRequest = Functions.makeHttpRequest({
  url: `https://api.github.com/user`,
  method: "GET",
  headers: { Authorization: `Bearer ${secrets.accessToken}` },
})

const [profileResponse] = await Promise.all([profileRequest])
console.log(profileResponse)

if (profileResponse.error) {
  throw Error(profileResponse.error)
} else {
  const followers = profileResponse.data.followers

  if (followers < 10) {
    return Functions.encodeString("Not enough followers to earn this Shiji")
  }
}

const editImageRequest = Functions.makeHttpRequest({
  url: `https://rest.apitemplate.io/v2/create-image`,
  method: "POST",
  headers: { Authorization: `Token ${secrets.imageApiKey}`, "Content-Type": "application/json" },
  params: {
    template_id: "1c077b23aaf7c198",
    expiration: "0",
  },

  data: JSON.stringify({
    overrides: [
      {
        name: "background-image",
        stroke: "grey",
        src: "https://www.pngitem.com/pimgs/m/79-794894_bouncer-github-octocat-hd-png-download.png",
      },
      {
        name: "text_quote",
        text: profileResponse.data.login,
        fontSize: 60,
        textBackgroundColor: "rgba(0,0,0)",
      },
      {
        name: "text_tags",
        text: "Github | Mr. Popular | Shiji",
        fontSize: 55,
        textBackgroundColor: "rgba(0, 0, 0)",
      },
    ],
  }),
})

const [editImageResponse] = await Promise.all([editImageRequest])

if (!editImageResponse.error) {
  console.log(editImageResponse.data.download_url_png)
} else {
  throw Error(editImageResponse.error)
}

const metadata = {
  name: "Shiji | Github |" + profileResponse.data.login,
  description: "A soulbound NFT that represents that this user has more than 10 Github Followers",
  image: editImageResponse.data.download_url_png,
  externalLink: profileResponse.data.blog,
  attributes: [
    {
      trait_type: "Email",
      value: profileResponse.data.email,
    },
    {
      trait_type: "Company",
      value: profileResponse.data.company,
    },
    {
      trait_type: "Location",
      value: profileResponse.data.location,
    },
    {
      trait_type: "Twitter",
      value: profileResponse.data.twitter_username,
    },
    {
      trait_type: "Followers",
      value: profileResponse.data.followers,
    },
    {
      trait_type: "Following",
      value: profileResponse.data.following,
    },
    {
      trait_type: "Public Repos",
      value: profileResponse.data.public_repos,
    },
    {
      trait_type: "Public Gists",
      value: profileResponse.data.public_gists,
    },
    {
      trait_type: "Created At",
      value: profileResponse.data.created_at,
    },
    {
      trait_type: "Updated At",
      value: profileResponse.data.updated_at,
    },
  ],
}

const metadataString = JSON.stringify(metadata)

const storeMetadataRequest = Functions.makeHttpRequest({
  url: `https://zixins-be1.adaptable.app/auth/store`,
  method: "POST",
  headers: { Authorization: `Bearer ${secrets.nftStorageApiKey}`, "Content-Type": "application/json" },
  data: { metadataString: metadataString },
})
const [storeMetadataResponse] = await Promise.all([storeMetadataRequest])

if (!storeMetadataResponse.error) {
  return Functions.encodeString(
    "https://" + storeMetadataResponse.data.value.cid + ".ipfs.nftstorage.link/metadata.json"
  )
} else {
  throw Error(storeMetadataResponse.data)
}
