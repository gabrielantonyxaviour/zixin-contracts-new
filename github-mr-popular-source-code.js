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
const image = args[0]
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
    return Functions.encodeUint256(1)
  } else {
    return Functions.encodeUint256(0)
  }
}
