# The purpose of this simulation is to show that if one has a network that is interconnected
# then if you regress the number of new incidences on the number of contagious cases
# then one will get a concave function. 

# Some notes: for simplicity of the simulation, we have people be contagious for 1 
# period, and have that period immediately follow the period they get sick. 
# This reflects the purpose of the exercise, which is to show the theoretical connection
# between a network effect and a concave SIR.

# Before starting, we set a random seed for replicability, and parameters. This has been run with many different seeds.
set.seed(1)
# N = Number of people, AveCont = Contact Factor, P = Probability of getting sick if contact sick, cutoff = fraction of friend that are also friends
N = 10000
AveCont = 5.5
P = 0.4
cutoff = 0.8

# Step 1 - Create the network. Part A = first-level connections
tmp = matrix(runif(N*N),N,N)
NetMat = matrix(c(0),N,N)
NetMat[which(tmp<(AveCont/N))] = 1
# Assume that relationships are symmetric
NetMat = pmax(NetMat,t(NetMat))
diag(NetMat)=1
oldNetMat = NetMat

# Part B of building network: Making some "friends of friends" direct contacts, too.
# This gives the interrelatedness of networks.
for (i in 1:N)
{
  tmp = which(oldNetMat[,i]==1)
  tmp2 = unique(which(oldNetMat[,tmp]==1) %% N)
  tmp2[tmp2==0]=N
# This assigns all potential second-degree connects a random number, unless
# the second-degree connections were also first-degree connections, in which case the 
# Connection holds for sure.
  NetMat[tmp2,i]= pmax(NetMat[tmp2,i],runif(length(tmp2)))
# Impose symmetry
  NetMat[i,tmp2]= NetMat[tmp2,i]
}
# Only some of the potential connections are realized
NetMat = 1*(NetMat>=(1-cutoff))


# Part 2 - rates of infection
# Infected is time period of infection for each individual
Infected = matrix(c(0),N,1)
# Start with 4 people infected
Infected[1:4]=1
# Calculate who is infected for periods 2 thru 100.
for (i in 2:100) {
  # Potentially get sick if contact with infected and never gotten infected so far. The pmin means that 
  # If someone is exposed twice it is as if they are exposed just once. An alternative would be
  # that such a person could get multiple draws to get sick. We can set P=1 to see that this is not the driving force
  # If you set P=1, I recommend setting AveCont very low (e.g. 2) and Cutoff very large (e.g. 0.9 or 1) to get meaningful network interconnectedness
  Output = (pmin(NetMat %*% matrix(1*(Infected==(i-1)),ncol=1),1) * matrix((1*(Infected==0)),ncol=1))
  Infected[Output==1] = runif(sum(Output))
  # Second term below ensures that previously-infected people are not considered reinfected
  Infected[which(Infected<P & Infected>0)]=i
  # Resets all of the non-infected people back to 0
  Infected[which(Infected<1)]=0
}
# What period has either all cases in the simultion infected, or this will be 100 if the disease is still running
MI = max(Infected)
# Count is the number of cases in each period
Count = matrix(c(0),MI,1)
for (i in 1:MI) {
  Count[i] = sum(Infected==i)
}
plot((1:MI),Count)
# Regression
Cum = cumsum(Count)
Sus = (N-Cum)/N
MaxCount = MI
if(Sus[MI]==0) {MaxCount=MI-1}
LY = log(Count)
LYS = LY - log(Sus)
out <- lm(LYS[2:MaxCount]~LY[1:(MaxCount-1)])

